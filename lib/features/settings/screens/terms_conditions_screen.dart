import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../models/legal_document.dart';
import '../providers/legal_documents_provider.dart';

class TermsConditionsScreen extends ConsumerWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    final termsAsync = ref.watch(
      legalDocumentsProvider(LegalDocumentType.termsConditions),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Terms & Conditions',
          style: theme.textTheme.titleLarge?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: foregroundColor,
            size: 20,
          ),
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ),
      body: termsAsync.when(
        data: (document) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Title Section
            Text(
              'Terms and Conditions',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${DateFormat.yMMMMd().format(document.lastUpdated)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            
            // Content sections - Split by newlines and create sections
            ...document.content.split('\n\n').map((section) {
              if (section.trim().isEmpty) return const SizedBox(height: 24);
              
              // Check if this is a section title (all caps or ends with ':')
              final isTitle = section.trim().toUpperCase() == section.trim() || 
                            section.trim().endsWith(':');
              
              if (isTitle) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 16), 
                  child: Text(
                    section.trim(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      height: 1.5,
                    ),
                  ),
                );
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 24), 
                child: Text(
                  section.trim(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onBackground.withOpacity(0.87),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
