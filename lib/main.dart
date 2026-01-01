import 'package:flutter/material.dart';
import 'app.dart';
import 'services/firebase/firebase_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  await FirebaseService.instance.initialize();
  
  // Reklam servisini başlat
  await AdService.instance.initialize();
  
  // Satın alma servisini başlat
  await PurchaseService.instance.initialize();
  
  runApp(const WardictApp());
}
