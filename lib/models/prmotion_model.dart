import 'package:flutter/material.dart';


class PromotionModel {
  String name;
  String imagePath;
  Color boxColor;

  PromotionModel({
    required this.name,
    required this.imagePath,
    required this.boxColor,
  });
  
  static List<PromotionModel> getPromotions(){
    List<PromotionModel> Promotions = [];
    Promotions.add(
      PromotionModel(
        name: 'Cinnamon Grand', 
        imagePath:'assets/images/grand.jpeg' , 
        boxColor: Color.fromARGB(255, 245, 150, 26)
    ));
      
      Promotions.add(
      PromotionModel(
        name: 'Cinnamon Life', 
        imagePath:'assets/images/life.jpg' , 
        boxColor: Color.fromARGB(255, 245, 150, 26)
    ));
      
      Promotions.add(
      PromotionModel(
        name: 'Galadari', 
        imagePath:'assets/images/galadari.jpg' , 
        boxColor: Color.fromARGB(255, 245, 150, 26)
    ));
  
        Promotions.add(
      PromotionModel(
        name: 'One Galle Face Mall', 
        imagePath:'assets/images/ogf.jpg' , 
        boxColor: Color.fromARGB(255, 245, 150, 26)
    ));
  
    return Promotions;
  }
}
