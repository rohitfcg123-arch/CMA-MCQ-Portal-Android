
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const offersAdminEmail = 'rohit.fcg123@gmail.com';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});
  @override State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  Map<String,dynamic> pricing = {
    'monthly': {'price':99.0,'discountType':'percent','discountValue':0.0,'discountName':''},
    'threeMonth': {'price':199.0,'discountType':'percent','discountValue':0.0,'discountName':''},
    'sixMonth': {'price':299.0,'discountType':'percent','discountValue':0.0,'discountName':''},
  };
  String promoType='percent', applyOn='discounted';
  bool active=true;
  String? editing;
  final code=TextEditingController(), name=TextEditingController(), value=TextEditingController();
  final maxUses=TextEditingController(text:'0'), perUser=TextEditingController(text:'1');
  String plans='monthly,threeMonth,sixMonth';
  DateTime? start, expiry;

  @override void initState(){super.initState(); load();}
  @override void dispose(){code.dispose();name.dispose();value.dispose();maxUses.dispose();perUser.dispose();super.dispose();}

  Future<void> load() async {
    final d=await FirebaseFirestore.instance.collection('settings').doc('access').get();
    final p=d.data()?['pricing'];
    if(p is Map) setState((){for(final k in pricing.keys){if(p[k] is Map) pricing[k]={...pricing[k]!,...Map<String,dynamic>.from(p[k])};}});
  }

  String label(String p)=>p=='monthly'?'Monthly':p=='threeMonth'?'3 Months':'6 Months';
  double finalPrice(String p){
    final x=pricing[p]!;
    final base=double.tryParse(x['price'].toString())??0;
    final v=double.tryParse(x['discountValue'].toString())??0;
    final d=x['discountType']=='fixed'?v:base*v/100;
    return (base-d).clamp(0,base);
  }

  Future<void> savePricing() async {
    await FirebaseFirestore.instance.collection('settings').doc('access').set({
      'pricing':pricing,'pricingUpdatedAt':FieldValue.serverTimestamp(),'pricingUpdatedBy':offersAdminEmail
    },SetOptions(merge:true));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pricing and offers saved.')));
  }

  void clearPromo(){setState((){editing=null;code.clear();name.clear();value.clear();maxUses.text='0';perUser.text='1';active=true;promoType='percent';applyOn='discounted';plans='monthly,threeMonth,sixMonth';start=null;expiry=null;});}

  Future<void> savePromo() async {
    final k=code.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'),'');
    if(k.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a promo code.')));return;}
    final selected=plans.split(',').where((e)=>e.isNotEmpty).toList();
    await FirebaseFirestore.instance.collection('promoCodes').doc(k).set({
      'code':k,'discountName':name.text.trim().isEmpty?k:name.text.trim(),
      'discountType':promoType,'discountValue':double.tryParse(value.text)??0,
      'applyOn':applyOn,'applicablePlans':selected,
      'maxUses':int.tryParse(maxUses.text)??0,'perUserLimit':int.tryParse(perUser.text)??1,
      'startDate':start==null?'':dateOnly(start!),'expiryDate':expiry==null?'':dateOnly(expiry!),
      'active':active,'updatedAt':FieldValue.serverTimestamp(),'updatedBy':offersAdminEmail,
      if(editing==null)'uses':0,'createdAt':FieldValue.serverTimestamp()
    },SetOptions(merge:true));
    clearPromo();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Promo code saved.')));
  }

  void editPromo(String id,Map<String,dynamic> x){
    setState((){editing=id;code.text=id;name.text=(x['discountName']??'').toString();value.text=(x['discountValue']??0).toString();
      promoType=(x['discountType']??'percent').toString();applyOn=(x['applyOn']??'discounted').toString();active=x['active']==true;
      maxUses.text=(x['maxUses']??0).toString();perUser.text=(x['perUserLimit']??1).toString();
      plans=List<String>.from(x['applicablePlans']??['monthly','threeMonth','sixMonth']).join(',');
      start=parseDate(x['startDate']??'');expiry=parseDate(x['expiryDate']??'');});
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Offers & Promo Codes')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Subscription Pricing & Offers',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),const Text('Set public prices and automatic direct discounts.'),
        for(final p in ['monthly','threeMonth','sixMonth']) priceEditor(p),
        const SizedBox(height:10),FilledButton.icon(onPressed:savePricing,icon:const Icon(Icons.save),label:const Text('Save Pricing')),
      ]))),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(editing==null?'Create Promo Code':'Edit Promo Code: '+editing!,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        TextField(controller:code,enabled:editing==null,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Promo Code',hintText:'NEWUSER10',border:OutlineInputBorder())),
        const SizedBox(height:10),TextField(controller:name,decoration:const InputDecoration(labelText:'Offer Name',border:OutlineInputBorder())),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:promoType,items:const[DropdownMenuItem(value:'percent',child:Text('Percentage')),DropdownMenuItem(value:'fixed',child:Text('Fixed Amount'))],onChanged:(v)=>setState(()=>promoType=v!),decoration:const InputDecoration(labelText:'Discount Type',border:OutlineInputBorder()))),
          const SizedBox(width:8),Expanded(child:TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Discount Value',border:OutlineInputBorder()))),
        ]),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:applyOn,items:const[DropdownMenuItem(value:'discounted',child:Text('Apply on discounted price')),DropdownMenuItem(value:'original',child:Text('Apply on original price'))],onChanged:(v)=>setState(()=>applyOn=v!),decoration:const InputDecoration(labelText:'Apply Discount On',border:OutlineInputBorder())),
        const SizedBox(height:10),const Text('Plans (tap to toggle)',style:TextStyle(fontWeight:FontWeight.bold)),
        Wrap(spacing:4,children:[for(final p in ['monthly','threeMonth','sixMonth'])FilterChip(label:Text(label(p)),selected:plans.split(',').contains(p),onSelected:(v)=>setState(()=>v?plans=plans.split(',').where((e)=>e.isNotEmpty).followedBy([p]).toSet().join(','):plans=plans.split(',').where((e)=>e!=p).join(',')))]),
        const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(controller:maxUses,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Max Uses (0 = unlimited)',border:OutlineInputBorder()))),const SizedBox(width:8),Expanded(child:TextField(controller:perUser,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Per User Limit',border:OutlineInputBorder())))]),
        Row(children:[
          Expanded(child:TextButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:start??DateTime.now());if(d!=null)setState(()=>start=d);},child:Text('Start: '+(start==null?'Any':dateOnly(start!))))),
          Expanded(child:TextButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:expiry??DateTime.now());if(d!=null)setState(()=>expiry=d);},child:Text('Expiry: '+(expiry==null?'None':dateOnly(expiry!))))),
        ]),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Promo Active'),value:active,onChanged:(v)=>setState(()=>active=v)),
        Row(children:[Expanded(child:FilledButton.icon(onPressed:savePromo,icon:const Icon(Icons.save),label:Text(editing==null?'Create Promo':'Update Promo'))),const SizedBox(width:8),OutlinedButton(onPressed:clearPromo,child:const Text('Clear'))]),
      ]))),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Existing Promo Codes',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('promoCodes').snapshots(),builder:(_,s){
          final docs=s.data?.docs??[]; if(docs.isEmpty)return const Padding(padding:EdgeInsets.all(12),child:Text('No promo codes created yet.'));
          return Column(children:docs.map((d){final x=d.data();return ListTile(
            title:Text(d.id+' — '+(x['discountName']??'').toString()),
            subtitle:Text((x['discountType']=='fixed'?'₹':'%')+x['discountValue'].toString()+' • '+(x['active']==true?'ACTIVE':'INACTIVE')+' • Uses: '+(x['uses']??0).toString()+'/'+(x['maxUses']??0).toString()),
            trailing:Wrap(children:[
              IconButton(onPressed:()=>editPromo(d.id,x),icon:const Icon(Icons.edit)),
              IconButton(onPressed:()=>FirebaseFirestore.instance.collection('promoCodes').doc(d.id).set({'active':x['active']!=true,'updatedAt':FieldValue.serverTimestamp()}, SetOptions(merge:true)),icon:Icon(x['active']==true?Icons.toggle_on:Icons.toggle_off)),
              IconButton(onPressed:()=>FirebaseFirestore.instance.collection('promoCodes').doc(d.id).delete(),icon:const Icon(Icons.delete_outline)),
            ]));}).toList());
        }),
      ]))),
    ]),
  );

  Widget priceEditor(String p){
    final x=pricing[p]!;
    return Card(margin:const EdgeInsets.only(top:10),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label(p),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
      TextFormField(initialValue:x['price'].toString(),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Original Price ₹',border:OutlineInputBorder()),onChanged:(v)=>pricing[p]!['price']=double.tryParse(v)??0),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:x['discountType'].toString(),items:const[DropdownMenuItem(value:'percent',child:Text('% Discount')),DropdownMenuItem(value:'fixed',child:Text('₹ Discount'))],onChanged:(v)=>setState(()=>pricing[p]!['discountType']=v!),decoration:const InputDecoration(labelText:'Discount Type',border:OutlineInputBorder())),
      const SizedBox(height:8),
      TextFormField(initialValue:x['discountValue'].toString(),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Discount Value',border:OutlineInputBorder()),onChanged:(v)=>pricing[p]!['discountValue']=double.tryParse(v)??0),
      const SizedBox(height:8),
      TextFormField(initialValue:(x['discountName']??'').toString(),decoration:const InputDecoration(labelText:'Offer Name',border:OutlineInputBorder()),onChanged:(v)=>pricing[p]!['discountName']=v),
      const SizedBox(height:5),Text('Final price: ₹'+finalPrice(p).toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.bold)),
    ])));
  }
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Payment Verification')),
    body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('payments').snapshots(),builder:(_,s){
      final docs=s.data?.docs??[]; if(docs.isEmpty)return const Center(child:Text('No payment requests found.'));
      return ListView.builder(itemCount:docs.length,itemBuilder:(_,i){final d=docs[i],x=d.data();return Card(child:ListTile(
        title:Text((x['name']??'Unknown').toString()+' — '+(x['email']??'').toString()),
        subtitle:Text('₹'+(x['finalAmount']??0).toString()+' • '+(x['plan']??'').toString()+' • UTR: '+(x['paymentId']??'-').toString()+'\\nStatus: '+(x['status']??'pending').toString()),
        trailing:PopupMenuButton<String>(onSelected:(v)=>updatePayment(context,d.id,x,v),itemBuilder:(_)=>const[PopupMenuItem(value:'approved',child:Text('Approve & Activate')),PopupMenuItem(value:'rejected',child:Text('Reject')),PopupMenuItem(value:'pending',child:Text('Mark Pending'))]),
      ));});
    }),
  );
  Future<void> updatePayment(BuildContext context,String id,Map<String,dynamic>x,String status)async{
    await FirebaseFirestore.instance.collection('payments').doc(id).set({'status':status,'verifiedAt':FieldValue.serverTimestamp(),'verifiedBy':offersAdminEmail},SetOptions(merge:true));
    if(status=='approved'){
      final email=(x['email']??'').toString().toLowerCase(); final groups=List<String>.from(x['groups']??[]);
      if(email.isNotEmpty){
        final q=await FirebaseFirestore.instance.collection('portalUsers').where('email',isEqualTo:email).limit(1).get();
        final ref=q.docs.isEmpty?FirebaseFirestore.instance.collection('portalUsers').doc():q.docs.first.reference;
        final plan=(x['plan']??'monthly').toString(); final n=plan=='sixMonth'?6:plan=='threeMonth'?3:1; final now=DateTime.now(); final end=DateTime(now.year,now.month+n,now.day);
        await ref.set({'email':email,'displayName':x['name']??'','phone':x['phone']??'','paymentStatus':'Paid','groups':groups,'accessType':groups.length>1?'Custom Access':groups.isEmpty?'No Access':groups.first,'plan':plan,'paymentId':x['paymentId']??'','amountPaid':x['finalAmount']??0,'startDate':FieldValue.serverTimestamp(),'expiryDate':Timestamp.fromDate(end),'accessUpdatedAt':FieldValue.serverTimestamp(),'accessUpdatedBy':offersAdminEmail},SetOptions(merge:true));
      }
    }
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(status=='approved'?'Payment approved and access activated.':'Payment marked '+status+'.')));
  }
}

String dateOnly(DateTime d)=>d.year.toString().padLeft(4,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.day.toString().padLeft(2,'0');
DateTime? parseDate(dynamic v){try{final a=v.toString().split('-');return a.length==3?DateTime(int.parse(a[0]),int.parse(a[1]),int.parse(a[2])):null;}catch(_){return null;}}
