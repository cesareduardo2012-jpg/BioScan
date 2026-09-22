import 'dart:io';

void main() {
  final file = File('lib/screens/usuarios_screen.dart');
  var content = file.readAsStringSync();

  // Find the build method
  final buildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {');
  if (buildStart == -1) {
    print('Could not find build method');
    return;
  }

  // Find the end of the class
  final classEnd = content.lastIndexOf('}');
  
  // Create the new build method and helpers
  final newContent = '''  @override
  Widget build(BuildContext context) {
    final auth = ServiceLocator.authService;
    final currentUser = auth.currentUser;
    final isOperatorMode = currentUser?.isOperador == true;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF008C83)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Configuración y Perfil'),
        backgroundColor: const Color(0xFF008C83),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsersData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (currentUser != null) _buildProfileSection(currentUser),
            if (currentUser?.isSuperAdmin == false && _activeCliente != null) _buildCompanySection(),
            if (currentUser?.isOperador == true && _adminUserForOperator != null) _buildAdminInfoSection(),
            if (currentUser?.isAdmin == true) _buildOperatorManagementSection(isOperatorMode),
            
            _buildPrinterSection(),
            _buildSimulatorSection(),
            
            _buildAboutSection(),
            _buildTeamSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildProfileSection(Usuario currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI PERFIL'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF008C83).withOpacity(0.15),
                  child: Icon(
                    currentUser.isAdmin ? Icons.admin_panel_settings : (currentUser.isSuperAdmin ? Icons.shield : Icons.person),
                    color: const Color(0xFF008C83),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.nombre,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Usuario: \${currentUser.username}', style: TextStyle(color: Colors.grey.shade700)),
                      Text('Correo: \${currentUser.correo}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currentUser.rol.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.lock_reset, color: Color(0xFF008C83)),
                  tooltip: 'Cambiar Mi Contraseña',
                  onPressed: _showChangeOwnPasswordDialog,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI EMPRESA'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF008C83)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeCliente!.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _activeCliente!.activo ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _activeCliente!.activo ? 'ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _activeCliente!.activo ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (_activeCliente!.empresa.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Razón Social: \${_activeCliente!.empresa}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                if (_activeCliente!.telefono.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Teléfono: \${_activeCliente!.telefono}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                if (_activeCliente!.correo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Correo: \${_activeCliente!.correo}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI ADMINISTRADOR'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
            ),
            title: Text(_adminUserForOperator!.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_adminUserForOperator!.correo),
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorManagementSection(bool isOperatorMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'OPERADORES DE LA CUENTA (MÁX. 1)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
            ),
            if (_operatorUser == null && !isOperatorMode)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C83),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Crear Operador'),
                onPressed: _showCreateOperatorDialog,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_operatorUser != null)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue.withOpacity(0.15),
                        child: const Icon(Icons.engineering, color: Colors.blue, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _operatorUser!.nombre,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _operatorUser!.activo ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _operatorUser!.activo ? 'ACTIVO' : 'INACTIVO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _operatorUser!.activo ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Usuario: \${_operatorUser!.username}', style: TextStyle(color: Colors.grey.shade700)),
                            Text('Rol: Operador Limitado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                        onPressed: _showEditOperatorDialog,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.key, size: 18),
                        label: const Text('Clave'),
                        onPressed: _showChangeOperatorPasswordDialog,
                      ),
                      TextButton.icon(
                        icon: Icon(
                          _operatorUser!.activo ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                          color: _operatorUser!.activo ? Colors.orange : Colors.green,
                        ),
                        label: Text(
                          _operatorUser!.activo ? 'Desactivar' : 'Activar',
                          style: TextStyle(color: _operatorUser!.activo ? Colors.orange : Colors.green),
                        ),
                        onPressed: _toggleOperatorStatus,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Eliminar Operador',
                        onPressed: _deleteOperator,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.person_add_disabled, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No hay usuario Operador registrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Puede registrar un usuario Operador para permitir mediciones limitadas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008C83),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Crear Usuario Operador'),
                    onPressed: _showCreateOperatorDialog,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrinterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('IMPRESORA TÉRMICA BLUETOOTH'),
            TextButton.icon(
              icon: const Icon(Icons.settings_bluetooth, size: 16, color: Color(0xFF008C83)),
              label: const Text('Gestionar', style: TextStyle(color: Color(0xFF008C83))),
              onPressed: _abrirConfigurarImpresora,
            ),
          ],
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _configuredPrinter != null
                          ? const Color(0xFF008C83).withOpacity(0.15)
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.print,
                        color: _configuredPrinter != null ? const Color(0xFF008C83) : Colors.grey.shade600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _configuredPrinter != null ? _configuredPrinter!['name']! : 'Impresora No Configurada',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _configuredPrinter != null ? Colors.green.shade100 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _configuredPrinter != null ? 'CONECTADA / LISTA' : 'NO CONFIGURADA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _configuredPrinter != null ? Colors.green.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _configuredPrinter != null
                                ? 'MAC: \${_configuredPrinter!['mac']} • Formato 58 mm'
                                : 'Vincule una impresora térmica portátil para imprimir tickets',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF008C83),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bluetooth_searching, size: 18),
                        label: Text(_configuredPrinter != null ? 'Cambiar Impresora' : 'Configurar Impresora'),
                        onPressed: _abrirConfigurarImpresora,
                      ),
                    ),
                    if (_configuredPrinter != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005267),
                          side: const BorderSide(color: Color(0xFF005267)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isPrintingTest
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005267)))
                            : const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Prueba'),
                        onPressed: _isPrintingTest ? null : _imprimirPruebaRapida,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HERRAMIENTAS DE DESARROLLO Y PRUEBAS'),
        Builder(
          builder: (ctx) {
            final isSimulationActive = BluetoothManager.instance.isSimulationMode;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSimulationActive ? Colors.deepPurple.shade300 : Colors.transparent,
                  width: 1.5,
                ),
              ),
              color: isSimulationActive ? Colors.deepPurple.shade50.withOpacity(0.6) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isSimulationActive ? Colors.deepPurple.shade100 : Colors.grey.shade100,
                          child: Icon(Icons.science_rounded, color: isSimulationActive ? Colors.deepPurple : Colors.grey.shade700, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Modo Simulador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSimulationActive ? Colors.green.shade100 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isSimulationActive ? 'SIMULADOR ACTIVO' : 'HARDWARE REAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSimulationActive ? Colors.green.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSimulationActive ? 'Conectado a BioScan-Demo • Batería 100%' : 'Buscando prototipo físico ESP32 vía BLE',
                                style: TextStyle(fontSize: 12, color: isSimulationActive ? Colors.deepPurple.shade700 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isSimulationActive,
                          activeThumbColor: Colors.deepPurple,
                          activeTrackColor: Colors.deepPurple.shade200,
                          onChanged: (enabled) {
                            BluetoothManager.instance.setSimulationMode(enabled);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enabled
                                      ? 'Modo Simulador Activo: Dispositivo BioScan-Demo listo para pruebas'
                                      : 'Modo Simulador Desactivado: Cambiando a hardware Bluetooth real',
                                ),
                                backgroundColor: enabled ? Colors.deepPurple : const Color(0xFF008C83),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ACERCA DE BIOSCAN'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.biotech, size: 48, color: Color(0xFF008C83)),
                const SizedBox(height: 12),
                const Text(
                  'BioScan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF005267)),
                ),
                const Text(
                  'Confianza en cada gota',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BioScan es una solución tecnológica enfocada en ayudar a pequeños y medianos productores y procesadores de lácteos a obtener información rápida sobre la calidad de la leche mediante un dispositivo portátil.\n\nFunciona como un "laboratorio de bolsillo" para obtener al instante datos vitales de pH, temperatura y densidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Versión de la App', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const Text('1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('NUESTRO EQUIPO'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'El equipo detrás de BioScan está comprometido con la innovación tecnológica en el sector lácteo, aportando pasión y experiencia para transformar el monitoreo de calidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 16),
                // Aquí se pueden agregar los integrantes específicos en un formato de lista profesional
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.people, color: Colors.teal),
                  ),
                  title: const Text('Equipo BioScan', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Desarrollo e Innovación'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}'''

  content = content.replaceRange(buildStart, classEnd + 1, newContent);
  file.writeAsStringSync(content);
}
