// lib/services/register_screen.dart
import 'dart:io';
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _idadeController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();

  int _tipoPerfil = 1;
  String? _sexo;
  XFile? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted ||
        await Permission.camera.isGranted ||
        await Permission.photos.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source);
        setState(() => _imageFile = pickedFile);
      } catch (e) {
        print("Erro ao pegar imagem: $e");
      }
    } else {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source);
        setState(() => _imageFile = pickedFile);
      } catch (e) {
        print("Erro fallback imagem: $e");
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF2E7D32),
              ),
              title: const Text('Galeria'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
              title: const Text('Câmera'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_cpfController.text.isEmpty || _cpfController.text.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Informe um CPF válido (apenas números)."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await authService.register(
      nome: _nomeController.text,
      email: _emailController.text,
      senha: _senhaController.text,
      tipoPerfil: _tipoPerfil,
      telefone: _telefoneController.text,
      idade: int.tryParse(_idadeController.text),
      sexo: _sexo,
      adminCode: _adminCodeController.text,
      fotoPerfil: _imageFile,
    );

    if (response == "OK") {
      await authService.registerLocalUser(
        cpf: _cpfController.text.trim(),
        email: _emailController.text.trim(),
        realPassword: _senhaController.text,
      );

      final userData = await authService.getUserData();
      final tipoPerfil = int.parse(userData['user_tipo_perfil'] ?? '1');
      UserProfile profile = UserProfile.trilheiro;
      if (tipoPerfil == 2) profile = UserProfile.guia;
      if (tipoPerfil == 3) profile = UserProfile.operador;

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainShell(profile: profile)),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background_login.png'),
                fit: BoxFit.cover,
              ),
              color: Colors.black,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),

                          const Text(
                            "Criar Conta",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: _imageFile != null
                                    ? FileImage(File(_imageFile!.path))
                                    : null,
                                child: _imageFile == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFFF6D00),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onPressed: _showImagePicker,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        controller: _nomeController,
                        label: 'Nome Completo*',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cpfController,
                        label: 'CPF (Somente Números)*',
                        icon: Icons.badge,
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'E-mail*',
                        icon: Icons.email,
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _senhaController,
                        label: 'Senha*',
                        icon: Icons.lock,
                        isObscure: true,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _telefoneController,
                              label: 'Telefone',
                              icon: Icons.phone,
                              type: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: _idadeController,
                              label: 'Idade',
                              icon: Icons.cake,
                              type: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildDropdown<String>(
                        value: _sexo,
                        items: ['Masculino', 'Feminino', 'Outro'],
                        label: 'Sexo',
                        icon: Icons.wc,
                        onChanged: (v) => setState(() => _sexo = v),
                      ),
                      const SizedBox(height: 16),

                      _buildDropdown<int>(
                        value: _tipoPerfil,
                        items: [1, 2, 3],
                        displayMap: {
                          1: 'Trilheiro',
                          2: 'Guia',
                          3: 'Operador de Base',
                        },
                        label: 'Tipo de Conta',
                        icon: Icons.badge,
                        onChanged: (v) => setState(() => _tipoPerfil = v ?? 1),
                      ),

                      if (_tipoPerfil > 1) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _adminCodeController,
                          label: 'Código de Administrador*',
                          icon: Icons.vpn_key,
                          hint: 'MAPL_ADMIN_2025',

                          validator: (v) => (v?.isEmpty ?? true)
                              ? 'Código obrigatório para funcionários'
                              : null,
                        ),
                      ],

                      const SizedBox(height: 30),

                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                'CRIAR CONTA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    TextInputType? type,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,

      validator:
          validator ??
          (v) => (v?.isEmpty ?? true) && label.contains('*')
              ? 'Campo obrigatório'
              : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required IconData icon,
    required Function(T?) onChanged,
    Map<T, String>? displayMap,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: const Color(0xFF1B5E20),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white70,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayMap != null ? displayMap[item]! : item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
