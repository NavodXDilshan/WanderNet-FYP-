import 'package:app/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Homepage extends StatelessWidget {
  Homepage({super.key});

  List<CategoryModel>categories = [];

  void _getCategories(){
    categories = CategoryModel.getCategories();
  }

  @override
  Widget build(BuildContext context) {
    _getCategories();
    return Scaffold(
      appBar: appBar(),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          SizedBox(height: 40,),
          categoriesSection()
        
        ],
      ),
    );
  }

  Column categoriesSection() {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Padding(
              padding: const EdgeInsets.only(left:20),
              child: Text(
                'Category',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600
                ),
              ),
            ),
            SizedBox(height:15),
            Container(
              height: 120,
              color: const Color.fromARGB(255, 255, 255, 255),
              child: ListView.separated(
                itemCount: categories.length,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  left:20,
                  right:20,
                ),
                separatorBuilder: (context, index) => SizedBox(width: 25,),
                itemBuilder: (context, index){
                  return Container(                 
                    width:100,
                    decoration: BoxDecoration(
                      color: categories[index].boxColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),                        
                    ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SvgPicture.asset(categories[index].iconPath),
                        ),
                      ),
                      Text(
                        categories[index].name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        )

                      ),
                    ],
                  ),
                  );
                },
              ),
            )
          ],
        );
  }

  Container _searchField() {
    return Container(
          margin: EdgeInsets.only(top:40,left:20, right:20),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.11),
                blurRadius: 40,
                spreadRadius: 0.0

              )
            ]
          ),

          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromARGB(255, 255, 255, 255),
              contentPadding: EdgeInsets.all(15),
              hintText: 'search',
              hintStyle: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SvgPicture.asset('assets/icons/Search.svg'),
              ),
              suffixIcon: Container(
                width:100,
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      VerticalDivider(
                        color: Colors.black,
                        indent: 10,
                        endIndent: 10,
                        thickness: 0.1,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset('assets/icons/Filter.svg'),
                      ),
                    ],
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              )
              
            ),
          ),
        );
  }

  AppBar appBar() {
    return AppBar(
      title: Text('HomePage',
      style: TextStyle(
        color: const Color.fromARGB(255, 0, 0, 0),
        fontSize: 20
      ),),

     centerTitle: true,
     backgroundColor: const Color.fromARGB(255, 240, 144, 9),
     leading: GestureDetector(
      onTap: () {

      } ,
    
      child: Container(
      margin: EdgeInsets.all(10),
      alignment: Alignment.center,
      child: SvgPicture.asset('assets/icons/Arrow - Left 2.svg',width: 20,height: 20,),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 240, 144, 9),
        borderRadius: BorderRadius.circular(10)
      ),
     ),),
     actions: [
      GestureDetector(
        onTap: () {

        },
      
      child: Container(
      margin: EdgeInsets.all(10),
      alignment: Alignment.center,
      width:30,
      child: SvgPicture.asset('assets/icons/dots.svg',),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 240, 144, 9),
        borderRadius: BorderRadius.circular(10)
      ),
     ),)
     ],
    );
  }
}

