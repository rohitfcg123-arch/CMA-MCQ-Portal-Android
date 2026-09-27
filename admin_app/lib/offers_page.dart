
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
  final ruleName = TextEditingController();
  final ruleValue = TextEditingController();
  String ruleType = 'percent';
  String selectedPlans = 'monthly,threeMonth,sixMonth';
  String selectedGroup = 'all';
  bool ruleActive = true;
  String? editingRuleId;
  List<Map<String,dynamic>> discountRules = [];
  static const groupOptions = <Map<String,String>>[
    {'key':'all','label':'All Groups'},
    {'key':'foundation','label':'CMA Foundation'},
    {'key':'inter-group-1','label':'CMA Intermediate Group 1'},
    {'key':'inter-group-2','label':'CMA Intermediate Group 2'},
    {'key':'inter-both','label':'Intermediate Both Groups'},
    {'key':'final-group-3','label':'CMA Final Group 3'},
    {'key':'final-group-4','label':'CMA Final Group 4'},
  ];

  @override void initState(){super.initState(); load();}
  @override void dispose(){code.dispose();name.dispose();value.dispose();maxUses.dispose();perUser.dispose();ruleName.dispose();ruleValue.dispose();super.dispose();}

  Future<void> load() async {
    final d=await FirebaseFirestore.instance.collection('settings').doc('access').get();
    final data=d.data()??{};
    final p=data['pricing'];
    if(p is Map) setState((){for(final k in pricing.keys){if(p[k] is Map) pricing[k]={...pricing[k]!,...Map<String,dynamic>.from(p[k])};}});
    final rr=data['discountRules'];
    if(rr is List) discountRules=rr.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
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

  List<String> _planList()=>selectedPlans.split(',').where((e)=>e.isNotEmpty).toList();
  String _groupLabel(String g){for(final x in groupOptions){if(x['key']==g)return x['label']!;}return g;}
  void _clearRule(){ruleName.clear();ruleValue.clear();setState((){editingRuleId=null;ruleType='percent';selectedPlans='monthly,threeMonth,sixMonth';selectedGroup='all';ruleActive=true;});}
  Future<void> _saveRule() async {
    final v=double.tryParse(ruleValue.text.trim()); final ps=_planList();
    if(v==null||v<0||ps.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Select at least one plan and enter a valid discount.')));return;}
    final id=editingRuleId??('rule_'+DateTime.now().millisecondsSinceEpoch.toString());
    final rule={'id':id,'name':ruleName.text.trim().isEmpty?'Direct Discount':ruleName.text.trim(),'discountType':ruleType,'discountValue':v,'plans':ps,'group':selectedGroup,'active':ruleActive};
    final next=[...discountRules.where((r)=>r['id']!=id),rule];
    await FirebaseFirestore.instance.collection('settings').doc('access').set({'discountRules':next,'discountRulesUpdatedAt':FieldValue.serverTimestamp(),'discountRulesUpdatedBy':offersAdminEmail},SetOptions(merge:true));
    if(!mounted)return; setState(()=>discountRules=next); _clearRule(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Discount rule saved.')));
  }
  void _editRule(Map<String,dynamic> r){setState((){editingRuleId=r['id']?.toString();ruleName.text=r['name']?.toString()??'';ruleValue.text=r['discountValue']?.toString()??'0';ruleType=r['discountType']?.toString()??'percent';selectedPlans=r['plans'] is List?List<String>.from(r['plans']).join(','):r['plans']?.toString()??'monthly,threeMonth,sixMonth';selectedGroup=r['group']?.toString()??'all';ruleActive=r['active']==true;});}
  Future<void> _deleteRule(String id) async {final next=discountRules.where((r)=>r['id']!=id).toList();await FirebaseFirestore.instance.collection('settings').doc('access').set({'discountRules':next},SetOptions(merge:true));if(mounted)setState(()=>discountRules=next);}
  Future<void> _toggleRule(Map<String,dynamic> r) async {final id=r['id'];final next=discountRules.map((x)=>x['id']==id?{...x,'active':x['active']!=true}:x).toList();await FirebaseFirestore.instance.collection('settings').doc('access').set({'discountRules':next},SetOptions(merge:true));if(mounted)setState(()=>discountRules=next);}

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

  Widget _discountRuleTile(Map<String,dynamic> r) {
    final rawPlans = r['plans'];
    final ps = rawPlans is List ? List<String>.from(rawPlans) : (rawPlans ?? '').toString().split(',').where((e)=>e.isNotEmpty).toList();
    final gs = _groupLabel(r['group']?.toString() ?? 'all');
    final val = (r['discountType']=='fixed' ? '₹' : '%') + (r['discountValue'] ?? 0).toString();
    final active = r['active'] == true;
    return Card(
      margin: const EdgeInsets.only(top:7),
      child: ListTile(
        title: Text(r['name']?.toString() ?? 'Direct Discount'),
        subtitle: Text(val + ' • ' + ps.map(label).join(' + ') + ' • ' + gs + ' • ' + (active ? 'ACTIVE' : 'INACTIVE')),
        trailing: Wrap(children:[
          IconButton(onPressed:()=>_editRule(r), icon:const Icon(Icons.edit)),
          IconButton(onPressed:()=>_toggleRule(r), icon:Icon(active ? Icons.toggle_on : Icons.toggle_off)),
          IconButton(onPressed:()=>_deleteRule(r['id'].toString()), icon:const Icon(Icons.delete_outline)),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Offers & Promo Codes')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Subscription Pricing & Offers',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:6),const Text('Set base prices once. Use one discount rule below for any plan + any group combination.'),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:TextFormField(initialValue:pricing['monthly']!['price'].toString(),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Monthly ₹',border:OutlineInputBorder()),onChanged:(v)=>pricing['monthly']!['price']=double.tryParse(v)??0)),
          const SizedBox(width:8),
          Expanded(child:TextFormField(initialValue:pricing['threeMonth']!['price'].toString(),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'3 Months ₹',border:OutlineInputBorder()),onChanged:(v)=>pricing['threeMonth']!['price']=double.tryParse(v)??0)),
          const SizedBox(width:8),
          Expanded(child:TextFormField(initialValue:pricing['sixMonth']!['price'].toString(),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'6 Months ₹',border:OutlineInputBorder()),onChanged:(v)=>pricing['sixMonth']!['price']=double.tryParse(v)??0)),
        ]),
        const SizedBox(height:10),FilledButton.icon(onPressed:savePricing,icon:const Icon(Icons.save),label:const Text('Save Base Prices')),
      ]))),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(editingRuleId==null?'Direct Discount Manager':'Edit Direct Discount',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:5),const Text('One place for all plans and all CMA groups. Select Monthly / 3 Months / 6 Months and choose All Groups, one group, or both Intermediate groups.'),
        const SizedBox(height:12),
        TextField(controller:ruleName,decoration:const InputDecoration(labelText:'Discount / Offer Name',border:OutlineInputBorder())),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:ruleType,items:const[DropdownMenuItem(value:'percent',child:Text('% Discount')),DropdownMenuItem(value:'fixed',child:Text('₹ Discount'))],onChanged:(v)=>setState(()=>ruleType=v!),decoration:const InputDecoration(labelText:'Discount Type',border:OutlineInputBorder()))),
          const SizedBox(width:8),
          Expanded(child:TextField(controller:ruleValue,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Discount Value',border:OutlineInputBorder()))),
        ]),
        const SizedBox(height:12),const Text('Apply to Plan(s)',style:TextStyle(fontWeight:FontWeight.bold)),
        Wrap(spacing:7,runSpacing:7,children:[
          for(final p in ['monthly','threeMonth','sixMonth']) FilterChip(label:Text(label(p)),selected:_planList().contains(p),onSelected:(v){final a=_planList();if(v&&!a.contains(p))a.add(p);if(!v)a.remove(p);setState(()=>selectedPlans=a.join(','));}),
          ActionChip(label:const Text('All Plans'),onPressed:()=>setState(()=>selectedPlans='monthly,threeMonth,sixMonth')),
        ]),
        const SizedBox(height:12),const Text('Apply to Group(s)',style:TextStyle(fontWeight:FontWeight.bold)),
        Wrap(spacing:7,runSpacing:7,children:[for(final g in groupOptions)FilterChip(label:Text(g['label']!),selected:selectedGroup==g['key'],onSelected:(v)=>setState(()=>selectedGroup=v?g['key']!:'all'))]),
        const SizedBox(height:7),const Text('“Intermediate Both Groups” applies the discount to Group 1 + Group 2. “All Groups” applies it to every CMA group.',style:TextStyle(fontSize:12,color:Colors.black54)),
        const SizedBox(height:10),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Discount Active'),value:ruleActive,onChanged:(v)=>setState(()=>ruleActive=v)),
        Row(children:[Expanded(child:FilledButton.icon(onPressed:_saveRule,icon:const Icon(Icons.save),label:Text(editingRuleId==null?'Save Discount':'Update Discount'))),const SizedBox(width:8),OutlinedButton(onPressed:_clearRule,child:const Text('Clear'))]),
        const SizedBox(height:12),
        const Divider(),const SizedBox(height:5),const Text('Saved Discount Rules',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        if(discountRules.isEmpty)const Padding(padding:EdgeInsets.all(10),child:Text('No direct discount rules yet.')),
        ...discountRules.map((r) => _discountRuleTile(r)),
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
