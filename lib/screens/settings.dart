import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/iap.dart';
import '../services/progress.dart';

const kPrivacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://example.com/privacy');
const kImprintUrl = String.fromEnvironment('IMPRINT_URL', defaultValue: 'https://example.com/imprint');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final iap = context.read<IapService>();
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('settings_title'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Premium card
            Card(
              color: st.premium ? const Color(0xFFDFF5E1) : cs.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.workspace_premium),
                      const SizedBox(width: 8),
                      Text(s.t('settings_premium'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                    const SizedBox(height: 8),
                    Text(st.premium ? s.t('settings_premium_active') : s.t('settings_premium_text')),
                    if (!st.premium) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: iap.product == null ? null : () => iap.buy(),
                        child: Text(iap.product == null ? s.t('settings_premium') : '${s.t('unlock_premium')} · ${iap.product!.price}'),
                      ),
                      TextButton(onPressed: () => iap.restore(), child: Text(s.t('settings_restore'))),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(s.t('settings_land')),
              trailing: DropdownButton<String>(
                value: st.land,
                underline: const SizedBox.shrink(),
                items: kLaender.map((l) => DropdownMenuItem(value: l.code, child: Text(l.nameDe))).toList(),
                onChanged: (v) => v == null ? null : st.setLand(v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(s.t('settings_lang')),
              trailing: DropdownButton<String>(
                value: st.lang,
                underline: const SizedBox.shrink(),
                items: S.languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => v == null ? null : st.setLang(v),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(s.t('settings_privacy')),
              onTap: () => launchUrl(Uri.parse(kPrivacyUrl), mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(s.t('settings_imprint')),
              onTap: () => launchUrl(Uri.parse(kImprintUrl), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 16),
            Text(s.t('settings_source'), style: TextStyle(color: cs.outline, fontSize: 12)),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (_, snap) => Text(
                '${s.t('settings_version')} ${snap.data?.version ?? ''} (${snap.data?.buildNumber ?? ''})',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
