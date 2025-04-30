import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/log_service.dart';

/// Serviço ORM (Object-Relational Mapping) para gerenciar a relação entre objetos e caixas
/// 
/// Este serviço fornece uma camada de abstração sobre o DatabaseHelper,
/// facilitando o carregamento e a manipulação de objetos relacionados.
class ORMService {
  static final ORMService _instance = ORMService._internal();
  factory ORMService() => _instance;
  
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final LogService _logService = LogService();
  
  // Cache para evitar múltiplas consultas ao banco de dados
  final Map<int, Box> _boxCache = {};
  final Map<int, Item> _itemCache = {};
  final Map<int, List<Item>> _boxItemsCache = {};
  
  ORMService._internal();

  /// Limpa todos os caches
  void clearCache() {
    _boxCache.clear();
    _itemCache.clear();
    _boxItemsCache.clear();
    _logService.debug('Cache do ORM limpo', category: 'orm');
  }

  /// Carrega uma caixa com todos os seus itens
  Future<Box> getBoxWithItems(int boxId) async {
    try {
      // Verificar se a caixa já está em cache
      if (_boxCache.containsKey(boxId) && _boxItemsCache.containsKey(boxId)) {
        final box = _boxCache[boxId]!;
        final items = _boxItemsCache[boxId]!;
        return box.copyWith(items: items);
      }

      // Carregar a caixa
      final box = await _databaseHelper.readBox(boxId);
      if (box == null) {
        throw Exception('Caixa não encontrada: $boxId');
      }

      // Carregar os itens da caixa
      final items = await _databaseHelper.readItemsByBoxId(boxId);

      // Atualizar o cache
      _boxCache[boxId] = box;
      _boxItemsCache[boxId] = items;
      for (final item in items) {
        _itemCache[item.id!] = item;
      }

      // Retornar a caixa com os itens
      return box.copyWith(items: items);
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar caixa com itens',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Carrega todas as caixas com seus itens
  Future<List<Box>> getAllBoxesWithItems() async {
    try {
      // Carregar todas as caixas
      final boxes = await _databaseHelper.readAllBoxes();
      final result = <Box>[];

      // Carregar os itens de cada caixa
      for (final box in boxes) {
        if (box.id != null) {
          final boxWithItems = await getBoxWithItems(box.id!);
          result.add(boxWithItems);
        }
      }

      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar todas as caixas com itens',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Cria uma nova caixa
  Future<Box> createBox(Box box) async {
    try {
      final newBox = await _databaseHelper.createBox(box);
      
      // Atualizar o cache
      _boxCache[newBox.id!] = newBox;
      _boxItemsCache[newBox.id!] = [];
      
      _logService.info(
        'Caixa criada: ${newBox.id} - ${newBox.name}',
        category: 'orm',
      );
      
      return newBox;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao criar caixa',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Atualiza uma caixa existente
  Future<int> updateBox(Box box) async {
    try {
      final result = await _databaseHelper.updateBox(box);
      
      // Atualizar o cache
      if (result > 0 && box.id != null) {
        _boxCache[box.id!] = box;
      }
      
      _logService.info(
        'Caixa atualizada: ${box.id} - ${box.name}',
        category: 'orm',
      );
      
      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao atualizar caixa',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Exclui uma caixa e todos os seus itens
  Future<int> deleteBox(int boxId) async {
    try {
      final result = await _databaseHelper.deleteBox(boxId);
      
      // Atualizar o cache
      if (result > 0) {
        _boxCache.remove(boxId);
        _boxItemsCache.remove(boxId);
        
        // Remover itens do cache
        _itemCache.removeWhere((key, item) => item.boxId == boxId);
      }
      
      _logService.info(
        'Caixa excluída: $boxId',
        category: 'orm',
      );
      
      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao excluir caixa',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Cria um novo item e o associa a uma caixa
  Future<Item> createItem(Item item) async {
    try {
      final newItem = await _databaseHelper.createItem(item);
      
      // Atualizar o cache
      _itemCache[newItem.id!] = newItem;
      
      // Atualizar o cache de itens da caixa
      if (_boxItemsCache.containsKey(newItem.boxId)) {
        _boxItemsCache[newItem.boxId]!.add(newItem);
      }
      
      _logService.info(
        'Item criado: ${newItem.id} - ${newItem.name} (Caixa: ${newItem.boxId})',
        category: 'orm',
      );
      
      return newItem;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao criar item',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Atualiza um item existente
  Future<int> updateItem(Item item) async {
    try {
      final result = await _databaseHelper.updateItem(item);
      
      // Atualizar o cache
      if (result > 0 && item.id != null) {
        final oldItem = _itemCache[item.id];
        _itemCache[item.id!] = item;
        
        // Se o item mudou de caixa, atualizar os caches de itens das caixas
        if (oldItem != null && oldItem.boxId != item.boxId) {
          if (_boxItemsCache.containsKey(oldItem.boxId)) {
            _boxItemsCache[oldItem.boxId]!.removeWhere((i) => i.id == item.id);
          }
          
          if (_boxItemsCache.containsKey(item.boxId)) {
            _boxItemsCache[item.boxId]!.add(item);
          }
        } else if (_boxItemsCache.containsKey(item.boxId)) {
          // Atualizar o item na lista de itens da caixa
          final index = _boxItemsCache[item.boxId]!.indexWhere((i) => i.id == item.id);
          if (index >= 0) {
            _boxItemsCache[item.boxId]![index] = item;
          } else {
            _boxItemsCache[item.boxId]!.add(item);
          }
        }
      }
      
      _logService.info(
        'Item atualizado: ${item.id} - ${item.name}',
        category: 'orm',
      );
      
      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao atualizar item',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Exclui um item
  Future<int> deleteItem(int itemId) async {
    try {
      // Obter o item antes de excluí-lo para saber a qual caixa ele pertence
      final item = _itemCache[itemId];
      
      final result = await _databaseHelper.deleteItem(itemId);
      
      // Atualizar o cache
      if (result > 0) {
        _itemCache.remove(itemId);
        
        // Remover o item da lista de itens da caixa
        if (item != null && _boxItemsCache.containsKey(item.boxId)) {
          _boxItemsCache[item.boxId]!.removeWhere((i) => i.id == itemId);
        }
      }
      
      _logService.info(
        'Item excluído: $itemId',
        category: 'orm',
      );
      
      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao excluir item',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Move um item para outra caixa
  Future<int> moveItemToBox(int itemId, int newBoxId) async {
    try {
      // Verificar se o item existe
      final item = await _databaseHelper.readItem(itemId);
      if (item == null) {
        throw Exception('Item não encontrado: $itemId');
      }
      
      // Verificar se a caixa de destino existe
      final box = await _databaseHelper.readBox(newBoxId);
      if (box == null) {
        throw Exception('Caixa de destino não encontrada: $newBoxId');
      }
      
      // Atualizar o item com a nova caixa
      final updatedItem = item.copyWith(
        boxId: newBoxId,
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      final result = await updateItem(updatedItem);
      
      _logService.info(
        'Item movido: $itemId - ${item.name} (Caixa antiga: ${item.boxId}, Nova caixa: $newBoxId)',
        category: 'orm',
      );
      
      return result;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao mover item para outra caixa',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Busca itens por nome, categoria ou descrição
  Future<List<Item>> searchItems(String query) async {
    try {
      // Carregar todos os itens se ainda não estiverem em cache
      if (_itemCache.isEmpty) {
        final items = await _databaseHelper.readAllItems();
        for (final item in items) {
          _itemCache[item.id!] = item;
        }
      }
      
      // Filtrar os itens pelo termo de busca
      final results = _itemCache.values.where((item) {
        final name = item.name.toLowerCase();
        final category = (item.category ?? '').toLowerCase();
        final description = (item.description ?? '').toLowerCase();
        final searchTerm = query.toLowerCase();
        
        return name.contains(searchTerm) || 
               category.contains(searchTerm) || 
               description.contains(searchTerm);
      }).toList();
      
      _logService.debug(
        'Busca de itens: "$query" - ${results.length} resultados',
        category: 'orm',
      );
      
      return results;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao buscar itens',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }

  /// Busca caixas por nome, categoria ou descrição
  Future<List<Box>> searchBoxes(String query) async {
    try {
      // Carregar todas as caixas se ainda não estiverem em cache
      if (_boxCache.isEmpty) {
        final boxes = await _databaseHelper.readAllBoxes();
        for (final box in boxes) {
          if (box.id != null) {
            _boxCache[box.id!] = box;
          }
        }
      }
      
      // Filtrar as caixas pelo termo de busca
      final results = _boxCache.values.where((box) {
        final name = box.name.toLowerCase();
        final category = box.category.toLowerCase();
        final description = (box.description ?? '').toLowerCase();
        final searchTerm = query.toLowerCase();
        
        return name.contains(searchTerm) || 
               category.contains(searchTerm) || 
               description.contains(searchTerm);
      }).toList();
      
      _logService.debug(
        'Busca de caixas: "$query" - ${results.length} resultados',
        category: 'orm',
      );
      
      return results;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao buscar caixas',
        error: e,
        stackTrace: stackTrace,
        category: 'orm',
      );
      rethrow;
    }
  }
}
