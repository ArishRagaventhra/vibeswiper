import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/config/supabase_config.dart';
import '../models/legal_document.dart';

final legalDocumentsProvider = FutureProvider.family<LegalDocument, LegalDocumentType>((ref, type) async {
  final response = await SupabaseConfig.client
      .rpc('get_current_legal_document', params: {
        'doc_type': type.toString(),
      });

  if (response == null || (response as List).isEmpty) {
    throw Exception('Document not found');
  }

  // The response is a list with a single item, so we take the first item
  final document = (response as List).first as Map<String, dynamic>;
  return LegalDocument.fromJson(document);
});
