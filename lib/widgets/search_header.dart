import 'package:flutter/material.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/orm_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/screens/item_detail_screen.dart';
import 'package:boxmagic/screens/box_detail_screen.dart';

class SearchHeader extends StatefulWidget {
  const SearchHeader({super.key});

  @override
  _SearchHeaderState createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ORMService _ormService = ORMService();
  final LogService _logService = LogService();
  
  List<Item> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    
    _performSearch(query);
  }
  
  Future<void> _performSearch(String query) async {
    if (query.length < 2) return; // Exigir pelo menos 2 caracteres
    
    setState(() {
      _isSearching = true;
      _showResults = true;
    });
    
    try {
      // Buscar itens que correspondam à consulta (case insensitive)
      final results = await _ormService.searchItems(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
      
      _logService.debug(
        'Busca realizada: "$query" - ${results.length} resultados',
        category: 'search',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao realizar busca: $e')),
        );
      }
      
      _logService.error(
        'Erro ao realizar busca',
        error: e,
        category: 'search',
      );
    }
  }
  
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
    _searchFocusNode.unfocus();
  }
  
  Future<void> _navigateToItemDetail(Item item) async {
    try {
      // Obter a caixa do item
      final box = await _ormService.getBoxWithItems(item.boxId);
      
      if (mounted) {
        // Navegar para a tela de detalhes do item
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(item: item, box: box),
          ),
        );
        
        // Limpar a busca após navegar
        _clearSearch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir detalhes do item: $e')),
        );
      }
      
      _logService.error(
        'Erro ao navegar para detalhes do item',
        error: e,
        category: 'navigation',
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Buscar objetos...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                ),
              ),
            ],
          ),
        ),
        
        // Resultados da busca
        if (_showResults)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            color: Theme.of(context).cardColor,
            child: _isSearching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _searchResults.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Nenhum resultado encontrado'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.category),
                            title: Text(item.name),
                            subtitle: FutureBuilder<Box?>(
                              future: _ormService.getBoxWithItems(item.boxId).then((box) => box),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Carregando...');
                                }
                                
                                if (snapshot.hasError || !snapshot.hasData) {
                                  return Text('Caixa ID: ${item.boxId}');
                                }
                                
                                final box = snapshot.data!;
                                return Text(
                                  'Caixa: ${box.name} (#${box.id.toString().padLeft(4, '0')})',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                );
                              },
                            ),
                            onTap: () => _navigateToItemDetail(item),
                          );
                        },
                      ),
          ),
      ],
    );
  }
}
