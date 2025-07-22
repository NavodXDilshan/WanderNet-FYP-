import 'package:flutter/material.dart';


class CategoryModel {
  String name;
  String iconPath;
  Color boxColor;

  CategoryModel({
    required this.name,
    required this.iconPath,
    required this.boxColor,
  });
  
  static List<CategoryModel> getCategories(){
    List<CategoryModel> categories = [];
    categories.add(
      CategoryModel(
        name: 'Hotels', 
        iconPath:'assets/icons/urban.svg' , 
        boxColor: Color(0xff92A3FD)
    ));
      
      categories.add(
      CategoryModel(
        name: 'Beaches', 
        iconPath:'assets/icons/beach.svg' , 
        boxColor: Color(0xffC588F2)
    ));
      
      categories.add(
      CategoryModel(
        name: 'Enjoyment', 
        iconPath:'assets/icons/sites.svg' , 
        boxColor: Color(0xff92A3FD)
    ));
  
        categories.add(
      CategoryModel(
        name: 'Wildlife', 
        iconPath:'assets/icons/wildlife.svg' , 
        boxColor: Color(0xffC588F2)
    ));
  
    return categories;
  }
}
