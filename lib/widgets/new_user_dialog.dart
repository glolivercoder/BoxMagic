import 'package:flutter/material.dart';
import 'package:boxmagic/models/user.dart';
import 'package:boxmagic/services/database_helper.dart';

class NewUserDialog extends StatefulWidget {
  final User? user;

  const NewUserDialog({super.key, this.user});

  @override
  _NewUserDialogState createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<NewUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _whatsappController;
  final _databaseHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _whatsappController = TextEditingController(text: widget.user?.whatsapp ?? '');
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();

    if (widget.user == null) {
      // Create new user
      final newUser = User(
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        whatsapp: _whatsappController.text.isEmpty ? null : _whatsappController.text,
        createdAt: now,
      );

      try {
        final savedUser = await _databaseHelper.createUser(newUser);
        if (mounted) {
          Navigator.pop(context, savedUser);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar usuário: $e')),
          );
        }
      }
    } else {
      // Update existing user
      final updatedUser = widget.user!.copyWith(
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        whatsapp: _whatsappController.text.isEmpty ? null : _whatsappController.text,
        updatedAt: now,
      );

      try {
        await _databaseHelper.updateUser(updatedUser);
        if (mounted) {
          Navigator.pop(context, updatedUser);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar usuário: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Editar Usuário' : 'Novo Usuário'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: João Silva',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  hintText: 'Ex: joao@exemplo.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Simple email validation
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Por favor, insira um email válido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (opcional)',
                  hintText: 'Ex: (11) 98765-4321',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saveUser,
          child: Text(isEditing ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }
}
