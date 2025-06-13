import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String? _userEmail;
  String? _userName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userEmail = user.email;
        _userName = doc['name'];
      });
    }
  }

  Future<void> _sendEmail() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final smtpServer = gmail('@gmail.com', '');

      final emailMessage = Message()
        ..from = Address('@gmail.com', 'BiteSmart Support')
        ..recipients.add('@example.com')
        ..subject = "Contact from $_userName ($_userEmail): ${_subjectController.text}"
        ..text = """
User: $_userName
Email: $_userEmail

Subject: ${_subjectController.text}

Message:
${_messageController.text}
""";

      await send(emailMessage, smtpServer);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message sent successfully!")),
      );

      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send: $e")),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact Us"),
        backgroundColor: Colors.orange,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _userEmail == null
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : ListView(
                children: [
                  Text("Logged in as:", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text("$_userName ($_userEmail)", style: TextStyle(color: Colors.orange)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _subjectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Subject",
                      labelStyle: TextStyle(color: Colors.orange),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _messageController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Your Message",
                      labelStyle: TextStyle(color: Colors.orange),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendEmail,
                    icon: const Icon(Icons.send),
                    label: Text(_isSending ? "Sending..." : "Send Message"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
