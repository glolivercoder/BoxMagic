import 'package:flutter/material.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/persistence_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/widgets/new_item_dialog.dart';
import 'package:boxmagic/widgets/new_box_dialog.dart';
import 'package:boxmagic/screens/item_detail_screen.dart';
import 'package:boxmagic/screens/object_recognition_screen.dart';
import 'package:boxmagic/screens/report_screen.dart';
import 'package:boxmagic/screens/boxes_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  // Métodos públicos para serem chamados de fora
  void showNewBoxDialog(BuildContext context) async {
    if (_itemsScreenState != null) {
      // Registrar a tentativa de criar uma nova caixa
      _itemsScreenState!._logService.info('Iniciando criação de nova caixa a partir da tela de itens', category: 'items_screen');

      // Criar uma nova caixa e depois atualizar a lista
      final boxesScreen = BoxesScreen();
      boxesScreen.showNewBoxDialog(context);

      // Recarregar os dados após criar a caixa
      // Aumentar o delay para garantir que o DatabaseHelper tenha tempo de processar a nova caixa
      _itemsScreenState!._logService.debug('Aguardando processamento da nova caixa', category: 'items_screen');
      await Future.delayed(const Duration(milliseconds: 1000));

      // Forçar uma atualização completa dos dados
      _itemsScreenState!._logService.info('Recarregando dados após criação de caixa', category: 'items_screen');
      await _itemsScreenState!._loadData();

      // Verificar se as caixas foram carregadas corretamente
      if (_itemsScreenState!._boxes.isEmpty) {
        _itemsScreenState!._logService.error('Falha ao carregar caixas após criação', category: 'items_screen');
      } else {
        _itemsScreenState!._logService.info('Caixas carregadas com sucesso após criação: ${_itemsScreenState!._boxes.length}', category: 'items_screen');
      }
    }
  }

  void generateReport(BuildContext context) {
    if (_itemsScreenState != null) {
      _itemsScreenState!._generateReport();
    }
  }

  void showObjectRecognition(BuildContext context) {
    if (_itemsScreenState != null) {
      _itemsScreenState!._showObjectRecognition();
    }
  }

  @override
  _ItemsScreenState createState() => _ItemsScreenState();
}

// Referência estática para acessar o estado da tela de itens
_ItemsScreenState? _itemsScreenState;

class _ItemsScreenState extends State<ItemsScreen> with AutomaticKeepAliveClientMixin {
  // Construtor com referência estática
  _ItemsScreenState() {
    _itemsScreenState = this;
  }
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final PersistenceService _persistenceService = PersistenceService();
  final LogService _logService = LogService();
  List<Item> _items = [];
  List<Box> _boxes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Item> _filteredItems = [];

  @override
  bool get wantKeepAlive => true; // Manter o estado quando mudar de aba

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _logService.info('Iniciando carregamento de dados na tela de itens', category: 'items_screen');

      // Depurar dados armazenados
      final debugInfo = await _persistenceService.debugShowAllKeys();
      _logService.debug('Dados armazenados: $debugInfo', category: 'items_screen');

      // Primeiro carregamos as caixas
      final boxes = await _databaseHelper.readAllBoxes();
      _logService.info('Caixas carregadas: ${boxes.length}', category: 'items_screen');

      // Log detalhado das caixas
      if (boxes.isNotEmpty) {
        for (int i = 0; i < boxes.length; i++) {
          _logService.debug('Caixa $i: ID=${boxes[i].id}, Nome=${boxes[i].name}', category: 'items_screen');
        }
      }

      if (boxes.isEmpty) {
        _logService.warning('Nenhuma caixa encontrada no DatabaseHelper, tentando carregar do SharedPreferences', category: 'items_screen');

        // Tentar carregar diretamente do SharedPreferences
        final data = await _persistenceService.loadAllData();
        final persistedBoxes = data['boxes'] as List<Box>;
        _logService.info('Caixas carregadas diretamente do SharedPreferences: ${persistedBoxes.length}', category: 'items_screen');

        // Log detalhado das caixas persistidas
        if (persistedBoxes.isNotEmpty) {
          for (int i = 0; i < persistedBoxes.length; i++) {
            _logService.debug('Caixa persistida $i: ID=${persistedBoxes[i].id}, Nome=${persistedBoxes[i].name}', category: 'items_screen');
          }
        }

        if (persistedBoxes.isNotEmpty) {
          _logService.info('Atualizando DatabaseHelper com ${persistedBoxes.length} caixas do SharedPreferences', category: 'items_screen');

          // Atualizar o DatabaseHelper com os dados carregados
          for (final box in persistedBoxes) {
            await _databaseHelper.createBox(box);
          }

          // Carregar novamente
          final updatedBoxes = await _databaseHelper.readAllBoxes();
          _logService.info('Caixas recarregadas após atualização: ${updatedBoxes.length}', category: 'items_screen');

          // Log detalhado das caixas atualizadas
          for (int i = 0; i < updatedBoxes.length; i++) {
            _logService.debug('Caixa atualizada $i: ID=${updatedBoxes[i].id}, Nome=${updatedBoxes[i].name}', category: 'items_screen');
          }

          setState(() {
            _boxes = updatedBoxes;
          });
        }
      } else {
        setState(() {
          _boxes = boxes;
        });
      }

      // Depois carregamos os itens
      final items = await _databaseHelper.readAllItems();
      _logService.info('Itens carregados: ${items.length}', category: 'items_screen');

      // Log detalhado dos itens
      if (items.isNotEmpty) {
        for (int i = 0; i < items.length; i++) {
          _logService.debug('Item $i: ID=${items[i].id}, Nome=${items[i].name}, BoxID=${items[i].boxId}', category: 'items_screen');
        }
      }

      setState(() {
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });

      _logService.info('Carregamento de dados concluído com sucesso', category: 'items_screen');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar dados na tela de itens',
        error: e,
        stackTrace: stackTrace,
        category: 'items_screen'
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar objetos: $e')),
        );
      }
    }
  }

  // Método para depuração - mostrar informações sobre as caixas
  void _debugBoxes() {
    if (_boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma caixa encontrada')),
      );
    } else {
      String boxesInfo = 'Caixas disponíveis (${_boxes.length}):\n';
      for (final box in _boxes) {
        boxesInfo += '- ID: ${box.id}, Nome: ${box.name}\n';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(boxesInfo),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Método para gerar relatório
  Future<void> _generateReport() async {
    if (_boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há caixas para gerar relatório'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Garantir que temos os dados mais recentes
    await _loadData();

    // Navegar para a tela de relatório
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          boxes: _boxes,
          items: _items,
        ),
      ),
    );
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                (item.category?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
                (item.id?.toString() ?? '').contains(query))
            .toList();
      }
    });
  }

  String _getBoxName(int boxId) {
    final box = _boxes.firstWhere(
      (box) => box.id == boxId,
      orElse: () => Box(
        name: 'Desconhecida',
        category: 'Desconhecida',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return box.name;
  }

  Future<void> _showNewItemDialog() async {
    _logService.info('Tentando abrir diálogo de novo item', category: 'items_screen');

    // Verificar se há caixas disponíveis
    _logService.debug('Verificando caixas disponíveis. Total: ${_boxes.length}', category: 'items_screen');

    if (_boxes.isEmpty) {
      _logService.warning('Tentativa de adicionar item sem caixas disponíveis', category: 'items_screen');

      // Tentar recarregar as caixas antes de mostrar o erro
      _logService.info('Tentando recarregar caixas antes de mostrar erro', category: 'items_screen');
      await _loadData();

      // Verificar novamente após recarregar
      if (_boxes.isEmpty) {
        _logService.error('Nenhuma caixa disponível mesmo após recarregar dados', category: 'items_screen');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você precisa criar uma caixa antes de adicionar objetos.'),
            ),
          );
        }
        return;
      }
    }

    _logService.info('Abrindo diálogo de novo item com ${_boxes.length} caixas disponíveis', category: 'items_screen');

    // Log detalhado das caixas que serão passadas para o diálogo
    for (int i = 0; i < _boxes.length; i++) {
      _logService.debug('Caixa $i para diálogo: ID=${_boxes[i].id}, Nome=${_boxes[i].name}', category: 'items_screen');
    }

    final result = await showDialog<Item>(
      context: context,
      builder: (context) => NewItemDialog(boxes: _boxes),
    );

    if (result != null) {
      _logService.info('Item criado com sucesso: ${result.name}', category: 'items_screen');
      await _loadData();
    } else {
      _logService.info('Diálogo de novo item cancelado pelo usuário', category: 'items_screen');
    }
  }

  Future<void> _showObjectRecognition() async {
    _logService.info('Tentando abrir tela de reconhecimento de objetos', category: 'items_screen');

    // Verificar se há caixas disponíveis
    _logService.debug('Verificando caixas disponíveis para reconhecimento. Total: ${_boxes.length}', category: 'items_screen');

    if (_boxes.isEmpty) {
      _logService.warning('Tentativa de reconhecer objeto sem caixas disponíveis', category: 'items_screen');

      // Tentar recarregar as caixas antes de mostrar o erro
      _logService.info('Tentando recarregar caixas antes de mostrar erro', category: 'items_screen');
      await _loadData();

      // Verificar novamente após recarregar
      if (_boxes.isEmpty) {
        _logService.error('Nenhuma caixa disponível para reconhecimento mesmo após recarregar dados', category: 'items_screen');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você precisa criar uma caixa antes de adicionar objetos.'),
            ),
          );
        }
        return;
      }
    }

    _logService.info('Abrindo tela de reconhecimento com ${_boxes.length} caixas disponíveis', category: 'items_screen');

    // Log detalhado das caixas que serão passadas para a tela de reconhecimento
    for (int i = 0; i < _boxes.length; i++) {
      _logService.debug('Caixa $i para reconhecimento: ID=${_boxes[i].id}, Nome=${_boxes[i].name}', category: 'items_screen');
    }

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ObjectRecognitionScreen(boxes: _boxes),
        ),
      );

      if (result != null) {
        _logService.info('Objeto reconhecido e salvo com sucesso', category: 'items_screen');
        await _loadData();
      } else {
        _logService.info('Reconhecimento de objeto cancelado pelo usuário', category: 'items_screen');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Chamada necessária para AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: null, // Removendo a AppBar duplicada
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar objetos',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterItems('');
                  },
                ),
              ),
              onChanged: _filterItems,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.category,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhum objeto encontrado',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showNewItemDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar manualmente'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _showObjectRecognition,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Identificar com câmera'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: const Icon(Icons.inventory_2, color: Colors.white),
                                ),
                                title: Text(item.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.category != null && item.category!.isNotEmpty)
                                      Text(item.category!),
                                    Text('Caixa: ${_getBoxName(item.boxId)}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEditItemDialog(item),
                                      tooltip: 'Editar objeto',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteItem(item),
                                      tooltip: 'Excluir objeto',
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ItemDetailScreen(
                                        item: item,
                                        boxName: _getBoxName(item.boxId),
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showObjectRecognition,
            tooltip: 'Identificar objeto com câmera',
            heroTag: 'items_camera_fab',
            backgroundColor: Colors.green,
            child: const Icon(Icons.camera_enhance),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _showNewItemDialog,
            tooltip: 'Adicionar novo objeto',
            heroTag: 'items_add_fab',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // Método para editar um item existente
  Future<void> _showEditItemDialog(Item item) async {
    _logService.info('Tentando editar item: ${item.name}', category: 'items_screen');

    // Verificar se há caixas disponíveis
    if (_boxes.isEmpty) {
      _logService.warning('Tentativa de editar item sem caixas disponíveis', category: 'items_screen');
      await _loadData();

      if (_boxes.isEmpty) {
        _logService.error('Nenhuma caixa disponível para edição', category: 'items_screen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro: Nenhuma caixa disponível'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Usar o mesmo diálogo de novo item, mas com os dados preenchidos
    final result = await showDialog<Item>(
      context: context,
      builder: (context) => NewItemDialog(
        boxes: _boxes,
        editItem: item,
      ),
    );

    if (result != null) {
      _logService.info('Item editado com sucesso: ${result.name}', category: 'items_screen');
      await _loadData();
    } else {
      _logService.info('Edição de item cancelada pelo usuário', category: 'items_screen');
    }
  }

  // Método para excluir um item
  Future<void> _deleteItem(Item item) async {
    _logService.info('Tentando excluir item: ${item.name}', category: 'items_screen');

    // Pedir confirmação antes de excluir
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Tem certeza que deseja excluir o objeto "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        _logService.info('Exclusão confirmada, excluindo item: ${item.id}', category: 'items_screen');
        await _databaseHelper.deleteItem(item.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Objeto excluído com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadData();
      } catch (e, stackTrace) {
        _logService.error(
          'Erro ao excluir item',
          error: e,
          stackTrace: stackTrace,
          category: 'items_screen',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir objeto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      _logService.info('Exclusão cancelada pelo usuário', category: 'items_screen');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
