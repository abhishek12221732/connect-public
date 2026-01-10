import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_config_service.dart';
import '../models/app_status_model.dart';
import 'package:flutter/services.dart';

class GlobalAlertWrapper extends StatelessWidget {
  final Widget child;

  const GlobalAlertWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<AppConfigService>(
          builder: (context, configService, _) {
            final status = configService.appStatus;

            // If not active, show nothing
            if (!status.isActive) return const SizedBox.shrink();

            // If blocking, show full screen overlay
            if (status.isBlocking) {
              return _buildBlockingOverlay(context, status);
            }
            
            // If non-blocking, we need to show a dialog. 
            // However, we can't easily push a dialog from here without context issues or duplicates.
            // A better approach for non-blocking is a "Banner" or a specialized overlay that allows pass-through.
            // BUT, strictly for the requirement of a "Dismissible Dialog", we can simulate it with a Stack entry 
            // that covers the screen but has a transparent background? 
            // Or better, just use a positioned floating card.
            
            return _buildNonBlockingOverlay(context, status, configService);
          },
        ),
      ],
    );
  }

  Widget _buildBlockingOverlay(BuildContext context, AppStatusModel status) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Stack(
        children: [
          // 1. Blur Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          
          // 2. Centered Content
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getIconForType(status.type),
                  const SizedBox(height: 20),
                  Text(
                    status.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status.message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (status.type == 'update')
                   const Padding(
                     padding: EdgeInsets.only(top: 8.0),
                     child: Text("Please check the store for updates.", style: TextStyle(fontWeight: FontWeight.w500)),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonBlockingOverlay(BuildContext context, AppStatusModel status, AppConfigService service) {
    // A simplified customized Dialog-like overlay
    return Stack(
      children: [
        // Semi-transparent barrier (optional, user can't click through unless we let them)
        // If it's non-blocking, we usually want them to dismiss it.
        Positioned.fill(
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black26)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 _getIconForType(status.type),
                 const SizedBox(height: 16),
                 Text(
                   status.title,
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 10),
                 Text(
                   status.message,
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                 ),
                 const SizedBox(height: 20),
                 ElevatedButton(
                   onPressed: () {
                     // We can't actually "dismiss" the provider state from here easily unless we add a local "hidden" state
                     // to the *Service* or to the *Widget*.
                     // Since service is global, hiding it there hides it for everyone? No, service is local instance listening to global doc.
                     // A simple way: The Service should support `dismissCurrentAlert()`.
                     // BUT, if the Firestore doc is still active, it will come back on restart.
                     // That's acceptable for "Announcement".
                     // For now, let's keep it simple: Add a dismiss method to Service is tricky if stream pushes again.
                     // Better: Keep a local "dismissedSessionIds" list in the service?
                     // Or simpler: Just hide this widget locally? 
                     // We can wrap this in a stateful widget.
                   }, 
                   // WAIT: We need to handle dismissal locally.
                   child: const Text("Got it"),
                 )
              ],
            ),
          ),
        )
      ],
    );
  }
  
  Widget _getIconForType(String type) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'maintenance':
        icon = Icons.build_circle_outlined;
        color = Colors.orange;
        break;
      case 'update':
        icon = Icons.system_update;
        color = Colors.blue;
        break;
      case 'warning':
        icon = Icons.warning_amber_rounded;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }
}

// ✨ STATEFUL WRAPPER FOR DISMISSAL LOGIC
class GlobalAlertHandler extends StatefulWidget {
  final Widget child;
  const GlobalAlertHandler({super.key, required this.child});

  @override
  State<GlobalAlertHandler> createState() => _GlobalAlertHandlerState();
}

class _GlobalAlertHandlerState extends State<GlobalAlertHandler> {
  // Store the message content that the user has already dismissed
  String? _dismissedMessageContent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Consumer<AppConfigService>(
          builder: (context, configService, _) {
            final status = configService.appStatus;

            // 1. Basic Checks
            if (!status.isActive) return const SizedBox.shrink();
            
            // 2. If blocked, ALWAYS show blocking overlay (cannot dismiss)
            if (status.isBlocking) {
               return const GlobalAlertWrapper(child: SizedBox.shrink())._buildBlockingOverlay(context, status);
            }

            // 3. If non-blocking, check if already dismissed
            if (_dismissedMessageContent == status.message) {
              return const SizedBox.shrink();
            }

            // 4. Show Dismissible Dialog
            // We reuse the build logic but wrapped in a container we can control
            return Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.black54)),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                     padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GlobalAlertWrapper(child: SizedBox.shrink())._getIconForType(status.type),
                         const SizedBox(height: 16),
                         Text(
                           status.title,
                           style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                           textAlign: TextAlign.center,
                         ),
                         const SizedBox(height: 10),
                         Text(
                           status.message,
                           textAlign: TextAlign.center,
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                               color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)
                             ),
                         ),
                         const SizedBox(height: 24),
                         SizedBox(
                           width: double.infinity,
                           child: FilledButton.tonal(
                             onPressed: () {
                               setState(() {
                                 _dismissedMessageContent = status.message;
                               });
                             },
                             style: FilledButton.styleFrom(
                               padding: const EdgeInsets.symmetric(vertical: 14),
                             ),
                             child: const Text("Dismiss"),
                           ),
                         )
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
