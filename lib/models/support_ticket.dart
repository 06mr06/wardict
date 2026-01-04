import 'package:cloud_firestore/cloud_firestore.dart';

/// Destek talebi durumu
enum TicketStatus {
  open,      // Açık - yanıt bekleniyor
  answered,  // Yanıtlandı
  closed,    // Kapatıldı
}

/// Tek bir mesaj (kullanıcı veya admin)
class SupportMessage {
  final String id;
  final String senderId;
  final String senderName;
  final bool isAdmin;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isAdmin,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      message: json['message'] ?? '',
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'isAdmin': isAdmin,
    'message': message,
    'createdAt': Timestamp.fromDate(createdAt),
    'isRead': isRead,
  };
}

/// Destek talebi (ticket)
class SupportTicket {
  final String id;
  final String oderId;
  final String userId;
  final String username;
  final String email;
  final String subject;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<SupportMessage> messages;
  final int unreadCount; // Admin yanıtı okunmamış sayısı

  const SupportTicket({
    required this.id,
    required this.oderId,
    required this.userId,
    required this.username,
    required this.email,
    required this.subject,
    this.status = TicketStatus.open,
    required this.createdAt,
    this.updatedAt,
    this.messages = const [],
    this.unreadCount = 0,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json, {String? docId}) {
    final messagesList = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    
    return SupportTicket(
      id: docId ?? json['id'] ?? '',
      oderId: json['oderId'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      subject: json['subject'] ?? '',
      status: TicketStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TicketStatus.open,
      ),
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] is Timestamp 
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt']))
          : null,
      messages: messagesList,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'oderId': oderId,
    'userId': userId,
    'username': username,
    'email': email,
    'subject': subject,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    'messages': messages.map((m) => m.toJson()).toList(),
    'unreadCount': unreadCount,
  };

  SupportTicket copyWith({
    String? id,
    String? oderId,
    String? userId,
    String? username,
    String? email,
    String? subject,
    TicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SupportMessage>? messages,
    int? unreadCount,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      oderId: oderId ?? this.oderId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Durum metni
  String get statusText {
    switch (status) {
      case TicketStatus.open:
        return 'Yanıt Bekleniyor';
      case TicketStatus.answered:
        return 'Yanıtlandı';
      case TicketStatus.closed:
        return 'Kapatıldı';
    }
  }

  /// Durum rengi
  int get statusColor {
    switch (status) {
      case TicketStatus.open:
        return 0xFFFFA000; // Orange
      case TicketStatus.answered:
        return 0xFF4CAF50; // Green
      case TicketStatus.closed:
        return 0xFF9E9E9E; // Grey
    }
  }
}
