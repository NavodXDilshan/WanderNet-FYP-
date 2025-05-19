import 'package:flutter/material.dart';
import 'package:app/components/search_bar.dart';

class Market extends StatefulWidget {
  const Market({super.key});

  @override
  State<Market> createState() => _MarketState();
}

class _MarketState extends State<Market> {
  SearchBar searchBar = SearchBar();
  @override
  Widget build(BuildContext context) {
    return Column(
      children:  [
        SearchField(text: 'Search',),
      ],
      
    );
  }
  

}