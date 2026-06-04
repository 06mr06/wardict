import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_ticket.dart';
import 'firebase/auth_service.dart';
import 'user_profile_service.dart';

/// Destek talepleri servisi - Firestore ile çalışır
class SupportService {
  static final SupportService instance = SupportService._();
  SupportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'support_tickets';

  /// Kullanıcının tüm destek taleplerini getir
  Future<List<SupportTicket>> getMyTickets() async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) return [];

      // Önce composite index ile dene
      try {
        final snapshot = await _firestore
            .collection(_collection)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        return snapshot.docs
            .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
            .toList();
      } catch (indexError) {
        // Index yoksa, sadece userId ile sorgula ve manuel sırala
        print('SupportService: Index hatası, fallback sorgu kullanılıyor: $indexError');
        
        final snapshot = await _firestore
            .collection(_collection)
            .where('userId', isEqualTo: userId)
            .get();

        final tickets = snapshot.docs
            .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
            .toList();
        
        // Manuel olarak tarihe göre sırala
        tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return tickets;
      }
    } catch (e) {
      print('SupportService.getMyTickets error: $e');
      return [];
    }
  }

  /// Tek bir destek talebini getir
  Future<SupportTicket?> getTicket(String ticketId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(ticketId).get();
      if (!doc.exists) return null;
      return SupportTicket.fromJson(doc.data()!, docId: doc.id);
    } catch (e) {
      print('SupportService.getTicket error: $e');
      return null;
    }
  }

  /// Yeni destek talebi oluştur
  Future<SupportTicket?> createTicket({
    required String subject,
    required String message,
  }) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) return null;

      final profile = await UserProfileService.instance.loadProfile();
      final username = profile.username;
      final email = AuthService.instance.userEmail ?? '';

      final ticketId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final firstMessage = SupportMessage(
        id: '${ticketId}_msg_1',
        senderId: userId,
        senderName: username,
        isAdmin: false,
        message: message,
        createdAt: now,
        isRead: true,
      );

      final ticket = SupportTicket(
        id: ticketId,
        oderId: userId, // oderId olarak userId kullan
        userId: userId,
        username: username,
        email: email,
        subject: subject,
        status: TicketStatus.open,
        createdAt: now,
        updatedAt: now,
        messages: [firstMessage],
        unreadCount: 0,
      );

      await _firestore.collection(_collection).doc(ticketId).set(ticket.toJson());

      return ticket;
    } catch (e) {
      print('SupportService.createTicket error: $e');
      return null;
    }
  }

  /// Mevcut talebe mesaj ekle
  Future<bool> sendMessage(String ticketId, String message) async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) return false;

      final profile = await UserProfileService.instance.loadProfile();
      final now = DateTime.now();

      final newMessage = SupportMessage(
        id: '${ticketId}_msg_${now.millisecondsSinceEpoch}',
        senderId: userId,
        senderName: profile.username,
        isAdmin: false,
        message: message,
        createdAt: now,
        isRead: true,
      );

      await _firestore.collection(_collection).doc(ticketId).update({
        'messages': FieldValue.arrayUnion([newMessage.toJson()]),
        'updatedAt': Timestamp.fromDate(now),
        'status': TicketStatus.open.name, // Kullanıcı yanıt verince tekrar açık
      });

      return true;
    } catch (e) {
      print('SupportService.sendMessage error: $e');
      return false;
    }
  }

  /// Tüm mesajları okundu olarak işaretle
  Future<void> markAsRead(String ticketId) async {
    try {
      final ticket = await getTicket(ticketId);
      if (ticket == null) return;

      final updatedMessages = ticket.messages.map((m) {
        if (m.isAdmin && !m.isRead) {
          return SupportMessage(
            id: m.id,
            senderId: m.senderId,
            senderName: m.senderName,
            isAdmin: m.isAdmin,
            message: m.message,
            createdAt: m.createdAt,
            isRead: true,
          );
        }
        return m;
      }).toList();

      await _firestore.collection(_collection).doc(ticketId).update({
        'messages': updatedMessages.map((m) => m.toJson()).toList(),
        'unreadCount': 0,
      });
    } catch (e) {
      print('SupportService.markAsRead error: $e');
    }
  }

  /// Okunmamış yanıt sayısını getir
  Future<int> getUnreadCount() async {
    try {
      final userId = AuthService.instance.userId;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('unreadCount', isGreaterThan: 0)
          .get();

      int total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['unreadCount'] as int? ?? 0);
      }
      return total;
    } catch (e) {
      print('SupportService.getUnreadCount error: $e');
      return 0;
    }
  }

  /// Destek talebini kapat
  Future<bool> closeTicket(String ticketId) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'status': TicketStatus.closed.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('SupportService.closeTicket error: $e');
      return false;
    }
  }

  /// Talep stream'i (real-time updates)
  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _firestore
        .collection(_collection)
        .doc(ticketId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return SupportTicket.fromJson(doc.data()!, docId: doc.id);
        });
  }

  /// Tüm kullanıcıların tüm taleplerini izle (Admin için Real-time)
  Stream<List<SupportTicket>> watchAllTickets() {
    return _firestore
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  /// Admin olarak mesaj gönder
  Future<bool> sendAdminMessage(String ticketId, String message) async {
    try {
      final now = DateTime.now();

      final newMessage = SupportMessage(
        id: '${ticketId}_admin_msg_${now.millisecondsSinceEpoch}',
        senderId: 'admin_support',
        senderName: 'Lugorena Destek',
        isAdmin: true,
        message: message,
        createdAt: now,
        isRead: false,
      );

      final ticketDoc = _firestore.collection(_collection).doc(ticketId);
      final ticketSnap = await ticketDoc.get();
      if (!ticketSnap.exists) return false;
      
      final currentUnread = (ticketSnap.data()?['unreadCount'] as int? ?? 0);

      await ticketDoc.update({
        'messages': FieldValue.arrayUnion([newMessage.toJson()]),
        'updatedAt': Timestamp.fromDate(now),
        'status': TicketStatus.answered.name,
        'unreadCount': currentUnread + 1,
      });

      return true;
    } catch (e) {
      print('SupportService.sendAdminMessage error: $e');
      return false;
    }
  }
}
