import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

const adminEmail = 'rohit.fcg123@gmail.com';
const activeMinutes = 10;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CMA Admin Portal',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0D3B3E)),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, s) {
      if (s.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final u = s.data;
      if (u == null) return const AdminLogin();
      if ((u.email ?? '').toLowerCase() != adminEmail) {
        FirebaseAuth.instance.signOut();
        return const AdminLogin(error: 'This account is not authorised as the Super Admin.');
      }
      return const Dashboard();
    },
  );
}

class AdminLogin extends StatefulWidget {
  final String? error;
  const AdminLogin({super.key, this.error});
  @override State<AdminLogin> createState() => _AdminLoginState();
}
class _AdminLoginState extends State<AdminLogin> {
  final email = TextEditingController(text: adminEmail);
  final password = TextEditingController();
  bool busy = false, hide = true;
  Future<void> login() async {
    setState(() => busy = true);
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      if ((c.user?.email ?? '').toLowerCase() != adminEmail) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(code: 'unauthorised');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'unauthorised' ? 'Only the authorised Rohit FCG account can use this app.' : 'Login failed: ${e.code}')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Card(
      margin: const EdgeInsets.all(24), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.admin_panel_settings, size: 64),
        const SizedBox(height: 12),
        const Text('CMA Admin Portal', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Super Admin access only'),
        const SizedBox(height: 20),
        TextField(controller: email, enabled: false, decoration: const InputDecoration(labelText: 'Admin email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
        if (widget.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(widget.error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Signing in…' : 'Login'))),
      ])),
    )),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Stream<QuerySnapshot<Map<String,dynamic>>> get users => FirebaseFirestore.instance.collection('portalUsers').snapshots();
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CMA Admin Dashboard'), actions: [
      IconButton(tooltip: 'Logout', onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))
    ]),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: users,
      builder: (_, s) {
        final docs = s.data?.docs ?? [];
        final now = DateTime.now();
        int active = 0, inactive10 = 0;
        for (final d in docs) {
          final t = _dateValue(d.data()['lastActive'] ?? d.data()['lastLogin']);
          if (t != null) {
            final age = now.difference(t).inMinutes;
            if (age <= activeMinutes) active++;
            if (age > 10 * 24 * 60) inactive10++;
          }
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            _metric('Registered Users', docs.length, Icons.people),
            _metric('Active Now', active, Icons.online_prediction),
            _metric('Inactive >10 Days', inactive10, Icons.person_off),
          ]),
          const SizedBox(height: 18),
          _tile(context, 'Users & Filters', Icons.people_alt, const UsersPage()),
          _tile(context, 'Activity & Last 10 Days', Icons.timeline, const ActivityPage()),
          _tile(context, 'Access Management', Icons.lock_person, const AccessPage()),
          _tile(context, 'Admin / Staff Management', Icons.manage_accounts, const StaffPage()),
          _tile(context, 'Reports & Downloads', Icons.download, const ReportsPage()),
        ]);
      },
    ),
  );
  Widget _metric(String title, int value, IconData icon) => SizedBox(width: 180, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text(title)]))));
  Widget _tile(BuildContext c, String title, IconData icon, Widget page) => Card(child: ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page))));
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  String activity = 'All', payment = 'All', access = 'All';
  DateTime? from, to;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Users & Filters')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('portalUsers').snapshots(),
      builder: (_, s) {
        final docs = s.data?.docs ?? [];
        final filtered = docs.where((d) {
          final x = d.data();
          final created = _dateValue(x['createdAt']);
          if (from != null && (created == null || created.isBefore(from!))) return false;
          if (to != null && (created == null || created.isAfter(to!.add(const Duration(days:1))))) return false;
          final last = _dateValue(x['lastActive'] ?? x['lastLogin']);
          final age = last == null ? 999999 : DateTime.now().difference(last).inDays;
          if (activity == 'Active' && age > 0) return false;
          if (activity == 'Active 5 Days' && age > 5) return false;
          if (activity == 'Active 10 Days' && age > 10) return false;
          if (activity == 'Inactive >10 Days' && age <= 10) return false;
          final p = (x['paymentStatus'] ?? 'Unpaid').toString();
          if (payment != 'All' && p.toLowerCase() != payment.toLowerCase()) return false;
          final a = (x['accessType'] ?? 'No Access').toString();
          if (access != 'All' && a != access) return false;
          return true;
        }).toList();
        return Column(children: [
          ExpansionTile(title: const Text('▼ User Filters'), initiallyExpanded: true, children: [
            Wrap(children: [
              _drop('Activity', activity, ['All','Active','Active 5 Days','Active 10 Days','Inactive >10 Days'], (v)=>setState(()=>activity=v!)),
              _drop('Payment', payment, ['All','Paid','Unpaid','Free','Expired'], (v)=>setState(()=>payment=v!)),
              _drop('Access', access, ['All','No Access','Foundation','Group 1','Group 2','All Groups','Custom Access'], (v)=>setState(()=>access=v!)),
            ]),
            Row(children: [
              Expanded(child: TextButton(onPressed: () async { final d=await showDatePicker(context:context, firstDate:DateTime(2020), lastDate:DateTime.now(), initialDate:from??DateTime.now()); if(d!=null)setState(()=>from=d); }, child: Text('From: ${from == null ? 'Any' : _fmt(from!)}'))),
              Expanded(child: TextButton(onPressed: () async { final d=await showDatePicker(context:context, firstDate:DateTime(2020), lastDate:DateTime.now(), initialDate:to??DateTime.now()); if(d!=null)setState(()=>to=d); }, child: Text('To: ${to == null ? 'Any' : _fmt(to!)}'))),
            ]),
          ]),
          Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (_,i) {
            final x=filtered[i].data(); final name=(x['displayName']??x['name']??'Unknown').toString(); final email=(x['email']??'').toString();
            return Card(child: ListTile(title: Text(name), subtitle: Text('$email\nPhone: ${x['phone']??'-'}\nLast active: ${_fmt(_dateValue(x['lastActive'] ?? x['lastLogin']))}'), isThreeLine:true, trailing: Text((x['accessType']??'No Access').toString())));
          })),
        ]);
      },
    ),
  );
  Widget _drop(String label,String value,List<String> values,ValueChanged<String?> cb)=>Padding(padding:const EdgeInsets.all(4),child:DropdownButton<String>(value:value,items:values.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:cb));
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('portalUsers').snapshots(),
      builder: (_,s) {
        final docs=s.data?.docs??[];
        final cutoff=DateTime.now().subtract(const Duration(days:10));
        final recent=docs.where((d){final t=_dateValue(d.data()['lastActive']??d.data()['lastLogin']);return t!=null&&t.isAfter(cutoff);}).toList();
        final old=docs.where((d){final t=_dateValue(d.data()['lastActive']??d.data()['lastLogin']);return t==null||t.isBefore(cutoff);}).toList();
        return ListView(padding:const EdgeInsets.all(16),children:[
          _section('Last 10 Days — ${recent.length}',recent),
          const SizedBox(height:16),
          _section('Inactive More Than 10 Days — ${old.length}',old),
        ]);
      },
    ),
  );
  Widget _section(String title,List<QueryDocumentSnapshot<Map<String,dynamic>>> docs)=>Card(child:ExpansionTile(title:Text(title),children:docs.map((d){final x=d.data();return ListTile(title:Text((x['displayName']??'Unknown').toString()),subtitle:Text('${x['email']??''}\nLast active: ${_fmt(_dateValue(x['lastActive']??x['lastLogin']))}'));}).toList()));
}

class AccessPage extends StatelessWidget {
  const AccessPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access Management')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('portalUsers').snapshots(),
      builder: (_,s)=>ListView(children:(s.data?.docs??[]).map((d){
        final x=d.data(); return ListTile(title:Text((x['displayName']??'Unknown').toString()),subtitle:Text((x['email']??'').toString()),trailing:TextButton(onPressed:()=>_edit(context,d.id,x),child:const Text('Permissions')));
      }).toList()),
    ),
  );
  Future<void> _edit(BuildContext c,String uid,Map<String,dynamic> x) async {
    bool universal=x['universalFree']==true;
    final groups=List<String>.from(x['groups']??const []);
    await showDialog(context:c,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(
      title:Text('Access: ${x['email']??uid}'),
      content:SizedBox(width:400,child:SingleChildScrollView(child:Column(children:[
        SwitchListTile(title:const Text('Universal Free Access'),value:universal,onChanged:(v)=>set(()=>universal=v)),
        for(final g in ['Foundation','Group 1','Group 2']) CheckboxListTile(title:Text(g),value:groups.contains(g),onChanged:(v)=>set(()=>v==true?groups.add(g):groups.remove(g))),
        CheckboxListTile(title:const Text('All Groups'),value:groups.contains('All Groups'),onChanged:(v)=>set(()=>v==true?groups.add('All Groups'):groups.remove('All Groups'))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{await FirebaseFirestore.instance.collection('portalUsers').doc(uid).set({'universalFree':universal,'groups':groups,'accessType':universal?'Universal Free':groups.isEmpty?'No Access':groups.contains('All Groups')?'All Groups':'Custom Access','accessUpdatedAt':FieldValue.serverTimestamp(),'accessUpdatedBy':adminEmail},SetOptions(merge:true));if(c.mounted)Navigator.pop(c);},child:const Text('Save Access'))],
    )));
  }
}

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin / Staff Management')),
    floatingActionButton: FloatingActionButton.extended(onPressed:()=>_request(context),label:const Text('Request / Invite'),icon:const Icon(Icons.person_add)),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('staffAccess').snapshots(),
      builder:(_,s)=>ListView(children:(s.data?.docs??[]).map((d){final x=d.data();return Card(child:ListTile(title:Text((x['email']??'').toString()),subtitle:Text('Role: ${x['role']??'Employee'}\nStatus: ${x['status']??'Pending'}\nLevel: ${x['accessLevel']??'Read'}'),trailing:Text((x['status']??'Pending').toString()));}).toList())),
  );
  Future<void> _request(BuildContext c) async {
    final e=TextEditingController(); String role='Employee', level='Read';
    await showDialog(context:c,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(
      title:const Text('Invite / Access Request'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
        DropdownButtonFormField<String>(value:role,items:['Admin','Manager','Employee'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>set(()=>role=v!),decoration:const InputDecoration(labelText:'Role')),
        DropdownButtonFormField<String>(value:level,items:['Read','Read & Write','Limited'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>set(()=>level=v!),decoration:const InputDecoration(labelText:'Access level')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{final email=e.text.trim().toLowerCase();if(email.isEmpty)return;await FirebaseFirestore.instance.collection('staffAccess').doc(email).set({'email':email,'role':role,'accessLevel':level,'status':'Pending Approval','requestedBy':adminEmail,'requestedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));if(c.mounted)Navigator.pop(c);},child:const Text('Send Request'))],
    )));
  }
}

class ReportsPage extends StatefulWidget { const ReportsPage({super.key}); @override State<ReportsPage> createState()=>_ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage> {
  String activity='All', status='All'; DateTime? from,to;
  Future<List<Map<String,dynamic>>> _data() async {
    final snap=await FirebaseFirestore.instance.collection('portalUsers').get();
    return snap.docs.map((d)=>{'Name':d.data()['displayName']??d.data()['name']??'', 'Email':d.data()['email']??'', 'Phone':d.data()['phone']??'', 'Registered':_fmt(_dateValue(d.data()['createdAt'])), 'Last Active':_fmt(_dateValue(d.data()['lastActive']??d.data()['lastLogin'])), 'Payment':d.data()['paymentStatus']??'', 'Access':d.data()['accessType']??''}).where((x){
      final dt=_parseFmt(x['Registered'] as String); if(from!=null&&(dt==null||dt.isBefore(from!)))return false; if(to!=null&&(dt==null||dt.isAfter(to!.add(const Duration(days:1)))))return false;
      if(status!='All'&&(x['Payment'] as String).toLowerCase()!=status.toLowerCase())return false; return true;
    }).toList();
  }
  Future<void> _excel() async {
    final rows=await _data(); final book=Excel.createExcel(); final sheet=book['Users'];
    sheet.appendRow(rows.isEmpty?['No data']:rows.first.keys.map((k)=>TextCellValue(k)).toList());
    for(final r in rows) sheet.appendRow(r.values.map((v)=>TextCellValue(v.toString())).toList());
    final bytes=book.encode(); if(bytes==null)return; await _share('cma_users.xlsx',Uint8List.fromList(bytes));
  }
  Future<void> _csv() async {
    final rows=await _data(); final keys=rows.isEmpty?['Name','Email','Phone','Registered','Last Active','Payment','Access']:rows.first.keys.toList();
    final out=StringBuffer()..writeln(keys.join(',')); for(final r in rows){out.writeln(keys.map((k)=>'"${r[k].toString().replaceAll('"','""')}"').join(','));}
    await _share('cma_users.csv',Uint8List.fromList(out.toString().codeUnits));
  }
  Future<void> _pdf() async {
    final rows=await _data(); final doc=pw.Document(); final keys=rows.isEmpty?['Name','Email','Phone','Registered','Last Active','Payment','Access']:rows.first.keys.toList();
    doc.addPage(pw.MultiPage(build:(_)=>[pw.Text('CMA MCQ User Report'),pw.SizedBox(height:10),pw.Table.fromTextArray(headers:keys,data:rows.map((r)=>keys.map((k)=>r[k].toString()).toList()).toList())]));
    await _share('cma_users.pdf',Uint8List.fromList(await doc.save()));
  }
  Future<void> _share(String name,Uint8List bytes) async {final dir=await getTemporaryDirectory();final f=File('${dir.path}/$name');await f.writeAsBytes(bytes);await SharePlus.instance.share(ShareParams(files:[XFile(f.path)],text:'CMA MCQ Portal report')); }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Reports & Downloads')),body:ListView(padding:const EdgeInsets.all(16),children:[
    ExpansionTile(title:const Text('▼ Report Filters'),initiallyExpanded:true,children:[
      Row(children:[Expanded(child:TextButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:from??DateTime.now());if(d!=null)setState(()=>from=d);},child:Text('From: ${from==null?'Any':_fmt(from!)}'))),Expanded(child:TextButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:to??DateTime.now());if(d!=null)setState(()=>to=d);},child:Text('To: ${to==null?'Any':_fmt(to!)}')))]),
      DropdownButtonFormField<String>(value:status,items:['All','Paid','Unpaid','Free','Expired'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>status=v!),decoration:const InputDecoration(labelText:'Payment / Status')),
    ]),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:_excel,icon:const Icon(Icons.table_view),label:const Text('Download Excel')),
    FilledButton.icon(onPressed:_pdf,icon:const Icon(Icons.picture_as_pdf),label:const Text('Download PDF')),
    FilledButton.icon(onPressed:_csv,icon:const Icon(Icons.file_download),label:const Text('Download CSV')),
  ]));
}

DateTime? _dateValue(dynamic v){if(v is Timestamp)return v.toDate();if(v is DateTime)return v;return null;}
String _fmt(DateTime? d)=>d==null?'-':'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
DateTime? _parseFmt(String s){try{final a=s.split(' ');final d=a.first.split('/');final t=a.length>1?a[1].split(':'):['0','0'];return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1]));}catch(_){return null;}}
