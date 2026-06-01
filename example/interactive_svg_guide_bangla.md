# Flutter SVG Pro: ইন্টারঅ্যাক্টিভ SVG সিলেকশন বিল্ড করার সম্পূর্ণ গাইড 🚀

সাধারণত ফ্ল্যাটারে SVG রেন্ডার করার জন্য আমরা `flutter_svg` প্যাকেজটি ব্যবহার করে থাকি। কিন্তু সমস্যা হলো, এই ধরনের স্ট্যান্ডার্ড রেন্ডারারগুলো কেবল স্ট্যাটিক ইমেজ হিসেবে কাজ করে। আপনি যদি একটি SVG ইমেজের নির্দিষ্ট কোনো পার্ট (যেমন: গাড়ির নির্দিষ্ট পার্টস, কোনো দেশের বা এলাকার মানচিত্রের নির্দিষ্ট অঞ্চল, কিংবা কোনো কাস্টম ডায়াগ্রামের বিভিন্ন কম্পোনেন্ট) এ ক্লিক করতে চান, কিংবা সেটিকে সিলেক্ট করে তার কালার পরিবর্তন করতে চান, তবে সাধারণ রেন্ডারার দিয়ে তা প্রায় অসম্ভব।

এখানেই এগিয়ে রয়েছে **`flutter_svg_pro`**! এটি একটি হাইলি-অপ্টিমাইজড, আইসোলেট-পাওয়ার্ড SVG পার্সিং এবং রেন্ডারিং ইঞ্জিন। যা আপনাকে প্রতিটি SVG পাত (Path) এবং গ্রুপকে আলাদাভাবে ডিটেক্ট করতে ও সেগুলোতে ট্যাপ ইন্টারঅ্যাকশন যুক্ত করতে সাহায্য করে।

এই গাইডে আমরা শিখবো কীভাবে আপনার ফ্ল্যাটার অ্যাপে খুব সহজে **`flutter_svg_pro`** ব্যবহার করে একটি চমৎকার ইন্টারঅ্যাক্টিভ SVG সিলেকশন ফিচার তৈরি করবেন।

---

## ১. প্রজেক্ট সেটআপ ও ইন্সটলেশন 🛠️

প্রথমে আপনার প্রজেক্টের `pubspec.yaml` ফাইলে প্যাকেজটি যুক্ত করুন:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg_pro: ^1.0.0
```

এরপর টার্মিনালে নিচের কমান্ডটি রান করে ডিপেন্ডেন্সি লোড করুন:
```bash
flutter pub get
```

---

## ২. SVG ফাইল রেডি করা (সবচেয়ে গুরুত্বপূর্ণ ধাপ) 📐

ইন্টারঅ্যাক্টিভ সিলেকশন কাজ করার জন্য আপনার SVG ফাইলের উপাদানগুলোতে নির্দিষ্ট **`id`** বা **`class`** থাকতে হবে। উদাহরণস্বরূপ, যদি আপনার কাছে একটি গাড়ির ড্রয়িং থাকে এবং আপনি সামনের অংশ ও দরজা আলাদাভাবে সিলেক্ট করতে চান, তবে আপনার SVG কোডটি এমন হওয়া উচিত:

```xml
<svg viewBox="0 0 500 500">
  <!-- গাড়ির হুড (Hood) -->
  <path id="hood" d="M 50 100 L 150 100 ..." fill="#cccccc" />

  <!-- গাড়ির দরজা (Door) -->
  <path id="door" d="M 150 100 L 250 100 ..." fill="#aaaaaa" />
</svg>
```
*মনে রাখবেন: `flutter_svg_pro` প্রতিটি SVG Path বা Group `<g>` এর ভেতরের `id` প্রোপার্টির ভিত্তিতে সেটিকে আইডেন্টিফাই করে।*

---

## ৩. অ্যাপে SVG অ্যাসেট কনফিগার করা 📂

আপনার SVG ফাইলটি প্রজেক্টের `assets/` ফোল্ডারে রাখুন (যেমন: `assets/car-front.svg`) এবং `pubspec.yaml` ফাইলে সেটি ডিক্লেয়ার করুন:

```yaml
flutter:
  assets:
    - assets/car-front.svg
```

---

## ৪. ধাপে ধাপে ইমপ্লিমেন্টেশন গাইড 🚀

ইন্টারঅ্যাক্টিভ সিলেকশন স্ক্রিন তৈরি করতে আমাদের ৩টি প্রধান কাজ করতে হবে:
1. `rootBundle` ব্যবহার করে SVG ফাইলটিকে টেক্সট স্ট্রিং আকারে রিড করা।
2. রেন্ডারিং সম্পন্ন হওয়ার সময় পর্যন্ত একটি সুন্দর লোডিং স্পিনার শো করা।
3. `SvgProViewer` উইজেটে স্ট্রিংটি পাস করা এবং ব্যবহারকারীর সিলেকশন ট্র্যাক করা।

### সম্পূর্ণ কোডিং উদাহরণ (Copy-Paste Ready) 💻

নিচের কোডটি কপি করে আপনার `lib/main.dart` ফাইলে বসিয়ে দিন:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg_pro/flutter_svg_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interactive SVG Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const InteractiveSvgScreen(),
    );
  }
}

class InteractiveSvgScreen extends StatefulWidget {
  const InteractiveSvgScreen({super.key});

  @override
  State<InteractiveSvgScreen> createState() => _InteractiveSvgScreenState();
}

class _InteractiveSvgScreenState extends State<InteractiveSvgScreen> {
  String? _rawSvgContent;
  String _selectionInfo = "";
  final Set<String> _selectedPartIds = {};

  @override
  void initState() {
    super.initState();
    _loadSvgAsset();
  }

  // অ্যাসেট থেকে SVG ফাইলটি স্ট্রিং আকারে লোড করার মেথড
  Future<void> _loadSvgAsset() async {
    try {
      final svgString = await rootBundle.loadString('assets/car-front.svg');
      setState(() {
        _rawSvgContent = svgString;
      });
    } catch (e) {
      setState(() {
        _selectionInfo = "SVG লোড করতে ব্যর্থ হয়েছে: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ইন্টারঅ্যাক্টিভ SVG পার্ট সিলেকশন 🚗'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ১. কার্ড ভিউ এর মাঝে SVG ডিসপ্লে করা
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _rawSvgContent == null
                      ? const Center(child: CircularProgressIndicator())
                      : SvgProViewer(
                          rawSvg: _rawSvgContent!,
                          // সিলেকশন মোড সেট করুন (সিঙ্গেল বা মাল্টিপল)
                          selectionMode: SvgSelectionMode.multiple,
                          // সিলেকশন কালার কাস্টমাইজ করুন
                          selectionHighlightColor: Colors.blue.withValues(alpha: 0.5),
                          // যখনই কোনো পার্ট সিলেক্ট করা হবে তখন কলব্যাক পাবে
                          onPartSelected: (SvgPart part) {
                            debugPrint("সিলেক্টেড পার্ট আইডি: ${part.id}");
                          },
                          // যখন টোটাল সিলেকশন পরিবর্তন হবে
                          onSelectionChanged: (List<SvgPart> selectedParts) {
                            setState(() {
                              _selectedPartIds.clear();
                              _selectedPartIds.addAll(selectedParts.map((p) => p.id));
                              
                              if (selectedParts.isEmpty) {
                                _selectionInfo = "";
                              } else {
                                _selectionInfo = selectedParts.map((p) => p.name).join(', ');
                              }
                            });
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // ২. সিলেকশন ফিডব্যাক শো করা
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'সিলেকশন স্ট্যাটাস:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[300],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedPartIds.isNotEmpty
                        ? 'সিলেক্টেড পার্টস: $_selectionInfo'
                        : 'যেকোনো বডি পার্টে টাচ করে সিলেক্ট করুন!',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ৫. এই প্যাকেজের অসাধারণ কিছু ফিচার এবং কেন এটি সেরা? 🌟

১. **আইসোলেট-পাওয়ার্ড হাই পারফরম্যান্স (Isolate Parsing)**:
   সাধারণত বড় আকারের SVG ফাইল পার্স করতে গেলে ফ্ল্যাটারের মেইন থ্রেড ব্লক হয়ে অ্যাপ ল্যাগ করে। `flutter_svg_pro` তে রয়েছে হাইব্রিড পার্সিং টেকনিক। ৫০ কেবির নিচের ফাইলগুলো খুব দ্রুত মেইন থ্রেডে লোড হয়, আর ৫০ কেবির বেশি সাইজের জটিল ফাইলগুলো অটোমেটিক্যালি একটি ব্যাকগ্রাউন্ড আইসোলেটে (Background Isolate) প্রসেস হয়। ফলে আপনার অ্যাপের রেন্ডারিং অলওয়েজ ১২০ FPS এ স্মুথ থাকবে!

২. **CSS এবং স্টাইল রেজিস্ট্রেশন সমর্থন**:
   এই প্যাকেজটি ইন্টারনাল এবং এক্সটারনাল সিএসএস স্টাইল শিট পার্স করতে সক্ষম। ইনলাইন স্টাইলিং ও সিএসএস ক্লাসের অগ্রাধিকার (Cascading Rules) চমৎকারভাবে প্রসেস হয়ে রেন্ডার হয়।

৩. **পিক্সেল পারফেক্ট হিট টেস্টিং**:
   কোঅর্ডিনেট ট্রান্সফর্মেশন ক্যালকুলেটরের মাধ্যমে স্ক্রিনের টাচ পয়েন্টকে ভেক্টর কোঅর্ডিনেটে রূপান্তর করে একদম নিখুঁত টাচ সিলেকশন নিশ্চিত করা হয়।

৪. **কাস্টম সিলেকশন মোড**:
   * `SvgSelectionMode.single` – ব্যবহারকারী একবারে কেবল একটি কম্পোনেন্ট সিলেক্ট করতে পারবেন।
   * `SvgSelectionMode.multiple` – একাধিক কম্পোনেন্ট একসাথে সিলেক্ট করা যাবে (যেমন: পার্টস চেকলিস্ট তৈরির জন্য উপযুক্ত)।

---

## ৬. কিছু কার্যকর টিপস ও ট্রিকস 💡

* **ক্লিন ভেক্টর ডেটা ব্যবহার করুন**: SVG ফাইলগুলো রেডি করার সময় অপ্রয়োজনীয় গ্রুপ বা মেটাডেটা বাদ দিয়ে ইলাস্ট্রেটর বা ফিগমা থেকে ক্লিন এক্সপোর্ট করার চেষ্টা করবেন।
* **সিলেকশন কালার কাস্টমাইজেশন**: `selectionHighlightColor` এ ট্র্যান্সপারেন্ট আলফা চ্যানেল ব্যবহার করুন (যেমন: `Colors.red.withValues(alpha: 0.5)`) যাতে সিলেকশনের পরেও নিচের ভেক্টর লাইনগুলো সুন্দরভাবে ফুটে ওঠে।

এখনই আপনার ফ্ল্যাটার অ্যাপে যুক্ত করুন **`flutter_svg_pro`** এবং ব্যবহারকারীদের উপহার দিন চমৎকার সব ইন্টারঅ্যাক্টিভ ডায়াগ্রাম সিলেকশন এক্সপেরিয়েন্স! 🚀
