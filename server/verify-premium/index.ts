// Supabase Edge Function "verify-premium".
//
// Checks, with Google's own servers, what the app reports locally:
//  * purchaseToken -> Google Play Developer API purchases.products.get
//    (a billing emulator / Lucky Patcher cannot forge a token Google accepts);
//  * integrityToken -> Play Integrity API decodeIntegrityToken
//    (detects patched or re-signed APKs: appRecognitionVerdict != PLAY_RECOGNIZED).
//
// Secrets (Supabase -> Edge Functions -> Secrets):
//   GOOGLE_SERVICE_ACCOUNT_JSON  full JSON key of a Google Cloud service account that
//                                (a) is invited in Play Console with "View financial data"
//                                and (b) belongs to the Cloud project linked to the apps
//                                under Play Console -> App integrity.
//
// Response: { purchaseValid: boolean|null, appRecognized: boolean|null, nonceOk: boolean }
// null = could not decide; the app then keeps its current state.

const ALLOWED_PACKAGES = new Set(["de.einbtest.app", "fr.examcivique.app"]);
const ALLOWED_PRODUCTS = new Set(["premium_unlock"]);
const SCOPES = [
  "https://www.googleapis.com/auth/androidpublisher",
  "https://www.googleapis.com/auth/playintegrity",
].join(" ");

type ServiceAccount = { client_email: string; private_key: string };

let cachedToken: { value: string; exp: number } | null = null;

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON is not set");
  const sa = JSON.parse(raw) as ServiceAccount;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: SCOPES,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claim}`)),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claim}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`token endpoint ${res.status}: ${await res.text()}`);
  const j = await res.json();
  cachedToken = { value: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return cachedToken.value;
}

async function checkPurchase(pkg: string, product: string, token: string): Promise<boolean | null> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}` +
    `/purchases/products/${product}/tokens/${encodeURIComponent(token)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${await googleAccessToken()}` } });
  if (res.status === 200) {
    const p = await res.json();
    return p.purchaseState === 0; // 0 purchased, 1 cancelled/refunded, 2 pending
  }
  // 400/404/410: Google does not know this token -> forged or revoked.
  if (res.status === 400 || res.status === 404 || res.status === 410) return false;
  console.error("purchase check", res.status, await res.text());
  return null; // 401/403/5xx: our configuration or Google's problem - do not punish the user
}

async function checkIntegrity(pkg: string, token: string, nonce: string) {
  const res = await fetch(`https://playintegrity.googleapis.com/v1/${pkg}:decodeIntegrityToken`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await googleAccessToken()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ integrity_token: token }),
  });
  if (!res.ok) {
    console.error("integrity decode", res.status, await res.text());
    return { appRecognized: null, nonceOk: false };
  }
  const payload = (await res.json()).tokenPayloadExternal ?? {};
  const verdict = payload.appIntegrity?.appRecognitionVerdict;
  return {
    appRecognized: verdict === "PLAY_RECOGNIZED" ? true : verdict === "UNRECOGNIZED_VERSION" ? false : null,
    nonceOk: payload.requestDetails?.nonce === nonce && payload.requestDetails?.requestPackageName === pkg,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const pkg = String(body.packageName ?? "");
  const product = String(body.productId ?? "");
  if (!ALLOWED_PACKAGES.has(pkg) || !ALLOWED_PRODUCTS.has(product)) return json({ error: "unknown app" }, 400);

  const out = { purchaseValid: null as boolean | null, appRecognized: null as boolean | null, nonceOk: false };
  try {
    if (typeof body.purchaseToken === "string" && body.purchaseToken) {
      out.purchaseValid = await checkPurchase(pkg, product, body.purchaseToken);
    }
    if (typeof body.integrityToken === "string" && typeof body.nonce === "string") {
      Object.assign(out, await checkIntegrity(pkg, body.integrityToken, body.nonce));
    }
  } catch (e) {
    console.error(e);
  }
  return json(out);
});
