// lib/features/profile/widgets/support_section.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// A widget section for displaying app support options.
class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  /// Launches the default email client to send a support request.
  ///
  /// Shows a [SnackBar] if the email client cannot be opened.
  /// 
  /// 
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Handle error
      debugPrint("Could not launch $url");
    }
  }


  Future<void> _launchSupportEmail(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'reach.feelings@gmail.com',
      queryParameters: {
        'subject': 'Support Request: Feelings App',
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        // This is a fallback for the rare case where the URL can't be launched.
        throw 'Could not launch email client.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not open email app. Please contact us at ${emailLaunchUri.path}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.help_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Support', style: titleStyle),
          ],
        ),
        const SizedBox(height: 12),
        // ✨ Card is wrapped in Padding to slightly reduce its width.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias, // Ensures the ripple stays within the rounded corners
            child: InkWell(
              onTap: () {
             // Reusing the support email logic you already have
            _launchURL('mailto:reach.feelings@gmail.com?subject=Feedback: Feelings App');
          },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Support',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Report an issue or send us feedback',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}