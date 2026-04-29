class Message {
  final String role;
  final String content;

  const Message({required this.role, required this.content});

  Message copyWith({String? role, String? content}) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}
