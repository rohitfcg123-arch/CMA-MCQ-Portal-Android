import 'offers_page.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

const superAdminEmail = 'rohit.fcg123@gmail.com';
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
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFAF6EE), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D3B3E)), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D3B3E), foregroundColor: Colors.white, elevation: 0), cardTheme: const CardThemeData(color: Color(0xFFFFFDF8), elevation: 2, margin: EdgeInsets.symmetric(vertical: 6))),
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
      final email = (u.email ?? '').trim().toLowerCase();
      if (email == superAdminEmail) return const Dashboard();
      return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
        future: FirebaseFirestore.instance.collection('staffAccess').doc(email).get(),
        builder: (_, staff) {
          if (staff.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final data = staff.data?.data();
          final status = (data?['status'] ?? 'Pending Approval').toString();
          final expiresAtRaw = data?['expiresAt'];
          DateTime? expiresAt;
          if (expiresAtRaw is Timestamp) expiresAt = expiresAtRaw.toDate();
          final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
          if (data == null || status != 'Approved' || expired) {
            FirebaseAuth.instance.signOut();
            return AdminLogin(error: expired ? 'Your staff access has expired. Contact the Super Admin.' : (status == 'Pending Approval' ? 'Account created. Waiting for admin approval.' : 'Staff access is not approved.'));
          }
          final permissions = <String, dynamic>{...(data?['permissions'] is Map ? Map<String, dynamic>.from(data?['permissions']) : const <String, dynamic>{})};
          return Dashboard(staffPermissions: permissions);
        },
      );
    },
  );
}

class AdminLogin extends StatefulWidget {
  final String? error;
  const AdminLogin({super.key, this.error});
  @override State<AdminLogin> createState() => _AdminLoginState();
}
class _AdminLoginState extends State<AdminLogin> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, hide = true;

  Future<void> login() async {
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || password.text.isEmpty) return;
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: password.text);
    } on FirebaseAuthException catch (ex) {
      if (!mounted) return;
      String msg = 'Login failed: ${ex.code}';
      if (ex.code == 'invalid-credential' || ex.code == 'wrong-password' || ex.code == 'user-not-found') msg = 'Invalid email or password.';
      if (ex.code == 'too-many-requests') msg = 'Too many attempts. Try again later.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> forgotPassword() async {
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent. Check your email inbox/spam.')));
    } on FirebaseAuthException catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: ${ex.code}')));
    }
  }

  Future<void> register() async {
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email and a password of at least 6 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: e, password: password.text);
      await credential.user?.sendEmailVerification();
      await FirebaseFirestore.instance.collection('staffAccess').doc(e).set({
        'email': e,
        'role': 'Employee',
        'accessLevel': 'Read',
        'status': 'Pending Approval',
        'requestedBy': e,
        'requestedAt': FieldValue.serverTimestamp(),
        'permissions': StaffPage._defaultPermissions('Employee', 'Read'),
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Ask the Super Admin to approve your access.')));
    } on FirebaseAuthException catch (ex) {
      if (!mounted) return;
      final msg = ex.code == 'email-already-in-use' ? 'This email already has an account. Use Login.' : 'Registration failed: ${ex.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        const Text('Super Admin / Staff Login'),
        const SizedBox(height: 20),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
        if (widget.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(widget.error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Signing in…' : 'Login'))),
        const SizedBox(height: 8),
        TextButton(onPressed: busy ? null : forgotPassword, child: const Text('Forgot Password?')),
        TextButton(onPressed: busy ? null : register, child: const Text('Create Staff Account')),
        const SizedBox(height: 4),
        const Text('Staff accounts require Super Admin approval.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]))),
    )),
  );
}

class Dashboard extends StatelessWidget {
  final Map<String, dynamic>? staffPermissions;
  const Dashboard({super.key, this.staffPermissions});

  bool _can(String key) => staffPermissions == null || staffPermissions![key] == true;
  static const activeWindow = Duration(minutes: 2);

  DateTime? _activeTime(Map<String, dynamic> x) => _dateValue(x['lastActive'] ?? x['lastSeen'] ?? x['lastLogin']);
  bool _isActive(Map<String, dynamic> x) {
    final t = _activeTime(x);
    if (t == null) return false;
    final age = DateTime.now().difference(t);
    return age >= const Duration(seconds: -10) && age <= activeWindow;
  }

  void _showActiveUsers(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final active = docs.where((d) => _isActive(d.data())).toList();
    active.sort((a,b) => (_activeTime(b.data()) ?? DateTime(1970)).compareTo(_activeTime(a.data()) ?? DateTime(1970)));
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFFFFFDF8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20,18,12,10), child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Active Users', style: TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:Color(0xFF082627))),
              SizedBox(height:3), Text('Students seen in the last 2 minutes',style:TextStyle(color:Color(0xFF65716F),fontSize:12)),
            ])),
            Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:const Color(0xFFE6EFED),borderRadius:BorderRadius.circular(20)),
              child:Text(active.length.toString()+' LIVE',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF0D3B3E)))),
          ])),
          const Divider(height:1),
          Expanded(child: active.isEmpty
            ? const Center(child: Column(mainAxisSize:MainAxisSize.min,children:[
                Icon(Icons.people_outline,size:54,color:Color(0xFF65716F)),SizedBox(height:10),
                Text('No student is active right now.',style:TextStyle(fontWeight:FontWeight.w700)),
                SizedBox(height:4),Text('The list updates automatically.',style:TextStyle(fontSize:12,color:Color(0xFF65716F)))
              ]))
            : ListView.separated(
                padding:const EdgeInsets.all(14),itemCount:active.length,
                separatorBuilder:(_,__)=>const SizedBox(height:7),
                itemBuilder:(_,i){
                  final x=active[i].data();
                  final name=(x['displayName']??x['name']??'Student').toString();
                  final email=(x['email']??'').toString();
                  final groups=x['groups'] is List?List<String>.from(x['groups']):const <String>[];
                  final names=groups.map((g)=>({'foundation':'CMA Foundation','inter-group-1':'CMA Intermediate Group 1','inter-group-2':'CMA Intermediate Group 2','final-group-3':'CMA Final Group 3','final-group-4':'CMA Final Group 4'}[g]??g)).join(' • ');
                  return Card(margin:EdgeInsets.zero,child:ListTile(
                    leading:Stack(children:[
                      CircleAvatar(backgroundColor:const Color(0xFFE6EFED),child:Text(name.isEmpty?'?':name.substring(0,1).toUpperCase(),style:const TextStyle(color:Color(0xFF0D3B3E),fontWeight:FontWeight.w900))),
                      Positioned(right:0,bottom:0,child:Container(width:12,height:12,decoration:BoxDecoration(color:const Color(0xFF2F7042),shape:BoxShape.circle,border:Border.all(color:const Color(0xFFFFFDF8),width:2))))
                    ]),
                    title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),
                    subtitle:Text(email+(names.isEmpty?'':'\n'+names)+'\nLast heartbeat: '+_fmt(_activeTime(x)),maxLines:3,overflow:TextOverflow.ellipsis),
                    isThreeLine:true,
                  ));
                },
              )),
        ]),
      )),
    );
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('CMA MCQ Portal',style:TextStyle(fontWeight:FontWeight.w800)),
        Text('Admin Control Center',style:TextStyle(fontSize:10,letterSpacing:1.2,color:Color(0xFFEAD39B)))
      ]),
      actions:[IconButton(tooltip:'Logout',onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout)),const SizedBox(width:6)],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('portalUsers').snapshots(),
      builder:(_,s){
        final docs=s.data?.docs??[];
        final activeDocs=docs.where((d)=>_isActive(d.data())).toList();
        final recent10=docs.where((d){final t=_activeTime(d.data());return t!=null&&DateTime.now().difference(t).inDays<=10;}).length;
        return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,34),children:[
          Container(
            padding:const EdgeInsets.fromLTRB(20,20,20,18),
            decoration:BoxDecoration(
              gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF0D3B3E),Color(0xFF082627)]),
              borderRadius:BorderRadius.circular(22),
              boxShadow:const[BoxShadow(color:Color(0x18082627),blurRadius:20,offset:Offset(0,8))]),
            child:Row(children:[
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('ADMIN CONTROL CENTER',style:TextStyle(color:Color(0xFFEAD39B),fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.4)),
                SizedBox(height:6),Text('Control your CMA portal',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
                SizedBox(height:5),Text('Manage students, access, payments, offers and staff from one place.',style:TextStyle(color:Color(0xFFD7E3E1),fontSize:12))
              ])),
              Container(width:54,height:54,decoration:BoxDecoration(color:Color(0x1FEAD39B),borderRadius:BorderRadius.circular(16),border:Border.all(color:Color(0x55EAD39B))),child:const Icon(Icons.admin_panel_settings,color:Color(0xFFEAD39B),size:30))
            ]),
          ),
          const SizedBox(height:14),
          Wrap(spacing:10,runSpacing:10,children:[
            _metric('Registered Users',docs.length,Icons.people_alt_outlined),
            _metricClickable(context,'Active Now',activeDocs.length,Icons.online_prediction,docs),
            _metric('Active in 10 Days',recent10,Icons.timeline),
          ]),
          const SizedBox(height:18),
          const Padding(padding:EdgeInsets.only(left:3,bottom:8),child:Text('Quick Access',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:Color(0xFF082627)))),
          GridView.count(
            crossAxisCount:MediaQuery.of(context).size.width>720?4:2,
            shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,
            childAspectRatio:MediaQuery.of(context).size.width>720?1.75:1.25,
            children:[
              if (_can('users.read')) _action(context,'Users & Filters','Students, groups & status',Icons.people_alt_outlined,const UsersPage()),
              if (_can('activity.read')) _action(context,'Activity','Live & last 10 days',Icons.timeline,const ActivityPage()),
              if (_can('access.read')) _action(context,'Access Management','Free, paid & groups',Icons.lock_person_outlined,const AccessPage()),
              if (_can('reports.read')) _action(context,'Reports','Excel, PDF & CSV',Icons.file_download_outlined,const ReportsPage()),
              if (_can('payments.read')) _action(context,'Payments','Verify subscriptions',Icons.payments_outlined,const PaymentsPage()),
              if (_can('staff.read')) _action(context,'Staff Management','Roles & permissions',Icons.manage_accounts_outlined,const StaffPage()),
            ],
          ),
          const SizedBox(height:14),
          Card(child:ListTile(
            leading:const CircleAvatar(backgroundColor:Color(0xFFE6EFED),child:Icon(Icons.bolt,color:Color(0xFF0D3B3E))),
            title:const Text('Live activity',style:TextStyle(fontWeight:FontWeight.w800)),
            subtitle:Text(activeDocs.isEmpty?'No students detected in the last 2 minutes.':activeDocs.length.toString()+' student'+(activeDocs.length==1?'':'s')+' currently active. Tap Active Now to see who.'),
            trailing:const Icon(Icons.chevron_right),onTap:()=>_showActiveUsers(context,docs),
          )),
        ]);
      },
    ),
  );

  Widget _metric(String title,int value,IconData icon) => SizedBox(
    width: 180,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0D3B3E)),
            const SizedBox(height: 7),
            Text(value.toString(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: Color(0xFF082627))),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF65716F), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );

  Widget _metricClickable(BuildContext context,String title,int value,IconData icon,List<QueryDocumentSnapshot<Map<String,dynamic>>> docs)=>GestureDetector(
    onTap:()=>_showActiveUsers(context,docs),
    child:Stack(children:[_metric(title,value,icon),Positioned(top:8,right:8,child:Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:const Color(0xFFEAD39B),borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.open_in_new,size:13,color:Color(0xFF082627))))]));

  Widget _action(BuildContext c,String title,String subtitle,IconData icon,Widget page)=>Card(margin:EdgeInsets.zero,child:InkWell(
    borderRadius:BorderRadius.circular(14),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>page)),
    child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFFE6EFED),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:const Color(0xFF0D3B3E),size:21)),
      const SizedBox(height:9),Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13,color:Color(0xFF0D3B3E))),
      const SizedBox(height:2),Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5,color:Color(0xFF65716F)))
    ]))));
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  String activity = 'All', payment = 'All', group = 'All';
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
          final selectedGroupKey = {'CMA Foundation':'foundation','CMA Intermediate Group 1':'inter-group-1','CMA Intermediate Group 2':'inter-group-2','CMA Final Group 3':'final-group-3','CMA Final Group 4':'final-group-4'}[group];
          final groups = x['groups'] is List ? List<String>.from(x['groups']) : const <String>[];
          if (selectedGroupKey != null && !groups.contains(selectedGroupKey)) return false;
          return true;
        }).toList();
        return Column(children: [
          ExpansionTile(title: const Text('▼ User Filters'), initiallyExpanded: true, children: [
            Wrap(children: [
              _drop('Activity', activity, ['All','Active','Active 5 Days','Active 10 Days','Inactive >10 Days'], (v)=>setState(()=>activity=v!)),
              _drop('Payment', payment, ['All','Paid','Unpaid','Free','Expired'], (v)=>setState(()=>payment=v!)),
              _drop('Group', group, ['All','CMA Foundation','CMA Intermediate Group 1','CMA Intermediate Group 2','CMA Final Group 3','CMA Final Group 4'], (v)=>setState(()=>group=v!)),
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

class AccessPage extends StatefulWidget {
  const AccessPage({super.key});
  @override State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  final TextEditingController _preApprovedEmail = TextEditingController();
  DateTime? _preApprovedExpiry;

  static const groupOptions = <Map<String, String>>[
    {'key': 'foundation', 'label': 'CMA Foundation'},
    {'key': 'inter-group-1', 'label': 'CMA Intermediate Group 1'},
    {'key': 'inter-group-2', 'label': 'CMA Intermediate Group 2'},
    {'key': 'final-group-3', 'label': 'CMA Final Group 3'},
    {'key': 'final-group-4', 'label': 'CMA Final Group 4'},
  ];

  Future<void> _setGlobalFree(bool enabled) async {
    await FirebaseFirestore.instance.collection('settings').doc('access').set({
      'siteWideFree': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': superAdminEmail,
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled
        ? 'Full app access is now FREE for EVERY student.'
        : 'Global free access turned OFF. Normal access rules are active again.')),
    );
  }

  Future<void> _grantFullAccess(String email, {DateTime? expiry}) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email address.')));
      return;
    }
    final expiryDate = expiry == null ? '' : '${expiry.year.toString().padLeft(4,'0')}-${expiry.month.toString().padLeft(2,'0')}-${expiry.day.toString().padLeft(2,'0')}';
    await FirebaseFirestore.instance.collection('access').doc(e).set({
      'email': e,
      'status': 'active',
      'accessType': 'all',
      'universalFull': true,
      'universalFree': true,
      'startDate': DateTime.now().toIso8601String().substring(0, 10),
      'expiryDate': expiryDate,
      'groups': groupOptions.map((g) => g['key']!).toList(),
      'overrides': <String, dynamic>{},
      'accessUpdatedAt': FieldValue.serverTimestamp(),
      'accessUpdatedBy': superAdminEmail,
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Full access granted to $e')));
  }

  Future<void> _preApprove() async {
    await _grantFullAccess(_preApprovedEmail.text, expiry: _preApprovedExpiry);
    if (!mounted) return;
    _preApprovedEmail.clear();
    setState(() => _preApprovedExpiry = null);
  }

  Future<void> _pickPreExpiry() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _preApprovedExpiry ?? DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null && mounted) setState(() => _preApprovedExpiry = d);
  }

  @override
  void dispose() {
    _preApprovedEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access Management')),
    body: Column(children: [
      Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pre-Approved Full Access', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Enter any email, even before registration. Access will apply automatically when that email signs up.'),
            const SizedBox(height: 10),
            TextField(
              controller: _preApprovedEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'student@example.com', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(_preApprovedExpiry == null ? 'No expiry' : 'Expiry: ${_fmt(_preApprovedExpiry)}')),
              TextButton.icon(onPressed: _pickPreExpiry, icon: const Icon(Icons.event), label: const Text('Set expiry')),
              if (_preApprovedExpiry != null) IconButton(onPressed: () => setState(() => _preApprovedExpiry = null), icon: const Icon(Icons.clear)),
            ]),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _preApprove, icon: const Icon(Icons.lock_open), label: const Text('Grant Full Access'))),
          ]),
        ),
      ),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('settings').doc('access').snapshots(),
        builder: (_, s) {
          final globalFree = s.data?.data()?['siteWideFree'] == true;
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Global Free Access', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(globalFree
                  ? 'ON — every student gets full app access without payment.'
                  : 'OFF — students follow their individual/free/paid access rules.'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(globalFree ? 'App FREE for EVERYONE' : 'Keep normal access rules'),
                  subtitle: Text(globalFree ? 'Turn OFF to restore payment and free-limit rules.' : 'Turn ON to make the complete app free for all students.'),
                  value: globalFree,
                  onChanged: _setGlobalFree,
                ),
              ]),
            ),
          );
        },
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('access').snapshots(),
          builder: (_, s) => ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: (s.data?.docs ?? []).map((d) {
              final x = d.data();
              final name = (x['name'] ?? x['displayName'] ?? 'Unknown').toString();
              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text("${x['email'] ?? d.id}\nAccess: ${x['universalFree'] == true ? 'Universal Free (individual)' : ((x['groups'] as List?)?.isNotEmpty == true ? 'Group access' : 'No group access')}"),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _grantFullAccess((x['email'] ?? d.id).toString()),
                        child: const Text('Full Access'),
                      ),
                      TextButton(
                        onPressed: () => _edit(context, d.id, x),
                        child: const Text('Permissions'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ]),
  );

  Future<void> _edit(BuildContext c, String uid, Map<String, dynamic> x) async {
    bool universal = x['universalFree'] == true;
    final groups = <String>{...(x['groups'] is List ? List<String>.from(x['groups']) : const <String>[])};

    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text("Access: ${x['email'] ?? uid}"),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(children: [
                SwitchListTile(
                  title: const Text('Universal Free Access'),
                  subtitle: const Text('FREE access to the complete app for this ONE student only.'),
                  value: universal,
                  onChanged: (v) => set(() => universal = v),
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Group Access', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final g in groupOptions)
                  CheckboxListTile(
                    title: Text(g['label']!),
                    value: groups.contains(g['key']),
                    onChanged: universal ? null : (v) => set(() => v == true ? groups.add(g['key']!) : groups.remove(g['key']!)),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final groupList = groups.toList();
                final email = (x['email'] ?? uid).toString().trim().toLowerCase();
                await FirebaseFirestore.instance.collection('access').doc(uid).set({
                  'email': email,
                  'name': x['name'] ?? x['displayName'] ?? '',
                  'universalFree': universal,
                  'universalFull': universal,
                  'groups': groupList,
                  'accessType': universal ? 'all' : (groupList.isEmpty ? 'partial' : 'partial'),
                  'status': 'active',
                  'accessUpdatedAt': FieldValue.serverTimestamp(),
                  'accessUpdatedBy': superAdminEmail,
                }, SetOptions(merge: true));
                final matches = await FirebaseFirestore.instance.collection('portalUsers').where('email', isEqualTo: email).limit(1).get();
                if (matches.docs.isNotEmpty) {
                  await matches.docs.first.reference.set({
                    'universalFree': universal,
                    'groups': groupList,
                    'accessType': universal ? 'Universal Free' : (groupList.isEmpty ? 'No Access' : 'Custom Access'),
                    'accessUpdatedAt': FieldValue.serverTimestamp(),
                    'accessUpdatedBy': superAdminEmail,
                  }, SetOptions(merge: true));
                }
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Save Access'),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin / Staff Management')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _request(context),
      label: const Text('Request / Invite'),
      icon: const Icon(Icons.person_add),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('staffAccess').snapshots(),
      builder: (_, s) => ListView(
        children: (s.data?.docs ?? []).map((d) {
          final x = d.data();
          final status = (x['status'] ?? 'Pending').toString();
          return Card(
            child: ListTile(
              title: Text((x['email'] ?? '').toString()),
              subtitle: Text('Role: ${x['role'] ?? 'Employee'}\nStatus: $status\nLevel: ${x['accessLevel'] ?? 'Read'}\nValidity: ${x['validityDays'] ?? '—'} days\nEmail: ${x['mailStatus'] ?? 'Not requested'}'),
              isThreeLine: true,
              trailing: Wrap(children: [
                IconButton(
                  tooltip: 'Reset Password',
                  icon: const Icon(Icons.lock_reset),
                  onPressed: () => _resetPassword((x['email'] ?? '').toString(), context),
                ),
                if (status == 'Pending Approval')
                  IconButton(
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check_circle),
                    onPressed: () => _setStatus(d.id, 'Approved'),
                  ),
                if (status == 'Pending Approval')
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.cancel),
                    onPressed: () => _setStatus(d.id, 'Rejected'),
                  ),
                if (status != 'Pending Approval')
                  PopupMenuButton<String>(
                    onSelected: (v) => _setStatus(d.id, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Approved', child: Text('Approve')),
                      PopupMenuItem(value: 'Suspended', child: Text('Suspend')),
                      PopupMenuItem(value: 'Revoked', child: Text('Revoke')),
                    ],
                  ),
              ]),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Future<void> _resetPassword(String email, BuildContext context) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset link sent to $email.')));
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reset link: ${e.code}')));
    }
  }

  Future<void> _setStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('staffAccess').doc(id).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': superAdminEmail,
    }, SetOptions(merge: true));
  }

  Future<void> _request(BuildContext context) async {
    final email = TextEditingController();
    final days = TextEditingController(text: '30');
    String role = 'Employee', level = 'Read';
    bool sendEmail = true;
    String? durationPreset = '30 days';
    await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: const Row(children: [Icon(Icons.mark_email_read_outlined), SizedBox(width: 10), Text('Invite employee')]),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Send a professional access invitation', style: TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), labelText: 'Employee email', hintText: 'employee@example.com')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: role, items: ['Admin','Manager','Employee'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => set(() => role = v!), decoration: const InputDecoration(labelText: 'Role'))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: level, items: ['Read','Read & Write','Limited'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => set(() => level = v!), decoration: const InputDecoration(labelText: 'Access level'))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: durationPreset, items: const ['7 days','30 days','90 days','180 days','365 days','Custom'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => set(() => durationPreset = v), decoration: const InputDecoration(labelText: 'Access validity')),
        if (durationPreset == 'Custom') ...[const SizedBox(height: 10), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule), labelText: 'Custom validity (days)'))],
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: sendEmail, onChanged: (v) => set(() => sendEmail = v ?? true), title: const Text('Queue professional invitation email'), subtitle: const Text('Subject: CMA MCQ Portal — Staff Access Invitation')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton.icon(icon: const Icon(Icons.send_outlined), label: const Text('Save & Send'), onPressed: () async {
          final mail = email.text.trim().toLowerCase();
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(mail)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid employee email.')));
            return;
          }
          int validityDays = int.tryParse(days.text.trim()) ?? 30;
          if (durationPreset != 'Custom') validityDays = int.tryParse(durationPreset!.split(' ').first) ?? 30;
          if (validityDays < 1) validityDays = 1;
          final expiry = DateTime.now().add(Duration(days: validityDays));
          try {
            await FirebaseFirestore.instance.collection('staffAccess').doc(mail).set({
              'email': mail, 'role': role, 'accessLevel': level, 'status': 'Approved', 'requestedBy': superAdminEmail,
              'requestedAt': FieldValue.serverTimestamp(), 'expiresAt': Timestamp.fromDate(expiry), 'validityDays': validityDays,
              'permissions': _defaultPermissions(role, level), 'mailStatus': sendEmail ? 'Queued' : 'Not requested',
              'mailSubject': 'CMA MCQ Portal — Staff Access Invitation',
            }, SetOptions(merge: true));
            String resultMessage = 'Employee access saved successfully.';
            if (sendEmail) {
              try {
                await FirebaseFirestore.instance.collection('mail').add({
                  'to': mail,
                  'message': {
                    'subject': 'CMA MCQ Portal — Staff Access Invitation',
                    'text': 'Hello,\n\nYou have been invited to access the CMA MCQ Portal as $role with $level permissions.\nAccess validity: $validityDays days.\nExpiry: ' + expiry.toLocal().toString().split('.').first + '.\n\nPlease open the CMA MCQ Staff/Admin app and complete registration using this email address. Your staff access has already been approved by the Super Admin.\n\nRegards,\nCMA MCQ Portal Admin',
                    'html': '<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;padding:24px;color:#22302f"><h2>CMA MCQ Portal — Staff Access Invitation</h2><p>Hello,</p><p>You have been invited as <b>$role</b> with <b>$level</b> access for <b>$validityDays days</b>.</p><p>Please open the CMA MCQ Staff/Admin app and complete registration using this email address. Your staff access has already been approved by the Super Admin.</p></div>'
                  },
                  'template': 'staff_access_invitation', 'accessStatus': 'Approved',
                  'role': role, 'accessLevel': level, 'validityDays': validityDays,
                  'expiresAt': Timestamp.fromDate(expiry), 'requestedBy': superAdminEmail,
                  'createdAt': FieldValue.serverTimestamp(), 'status': 'queued'
                });
              } catch (_) {
                resultMessage = 'Access saved, but invitation email could not be queued. Check Firebase mail configuration.';
              }
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage)));
          } on FirebaseException catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save employee access: ${e.code} — ${e.message ?? 'Permission or Firebase error'}')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save employee access: $e')));
          }
        }),
      ],
    )));
  }
  static Map<String, dynamic> _defaultPermissions(String role, String level) {
    if (level == 'Limited') {
      return {'users.read': true, 'activity.read': true, 'reports.read': false, 'payments.read': false, 'access.write': false, 'staff.write': false, 'settings.write': false};
    }
    final write = level == 'Read & Write';
    return {
      'users.read': true, 'users.write': write,
      'activity.read': true,
      'reports.read': true, 'reports.excel': true, 'reports.pdf': true, 'reports.csv': true,
      'payments.read': role != 'Employee',
      'access.read': role != 'Employee', 'access.write': write && role != 'Employee',
      'staff.read': role == 'Admin', 'staff.write': false,
      'settings.read': role == 'Admin', 'settings.write': false,
    };
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
    sheet.appendRow(rows.isEmpty ? [TextCellValue('No data')] : rows.first.keys.map((k)=>TextCellValue(k)).toList());
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

DateTime? _dateValue(dynamic v){if(v is Timestamp)return v.toDate();if(v is DateTime)return v;if(v is String){return DateTime.tryParse(v); }return null;}
String _fmt(DateTime? d)=>d==null?'-':'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
DateTime? _parseFmt(String s){try{final a=s.split(' ');final d=a.first.split('/');final t=a.length>1?a[1].split(':'):['0','0'];return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1]));}catch(_){return null;}}