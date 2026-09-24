import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

const portalUrl='https://rohitfcg123-arch.github.io/CMA-MCQ-Portal-Android/index.html';
String? nativeBridgePassword;

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await Firebase.initializeApp(options:DefaultFirebaseOptions.currentPlatform);
 runApp(const App());
}
class App extends StatelessWidget{
 const App({super.key});
 @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'CMA MCQ Portal',
  theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF0D3B3E)),useMaterial3:true),home:const AuthGate());
}
class AuthGate extends StatelessWidget{
 const AuthGate({super.key});
 @override Widget build(BuildContext c)=>StreamBuilder<User?>(stream:FirebaseAuth.instance.userChanges(),builder:(c,s){
  if(s.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator()));
  final u=s.data;if(u==null)return const AuthScreen();return u.emailVerified?const Portal():const AuthScreen();
 });
}
class AuthScreen extends StatefulWidget{const AuthScreen({super.key});@override State<AuthScreen> createState()=>_AuthScreenState();}
class _AuthScreenState extends State<AuthScreen>{
 final f=GlobalKey<FormState>();final name=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),pass=TextEditingController(),confirm=TextEditingController();
 bool reg=false,busy=false,hide=true,isError=false;String message='';
 @override void dispose(){name.dispose();phone.dispose();email.dispose();pass.dispose();confirm.dispose();super.dispose();}
 String? req(String? v,String n)=>(v==null||v.trim().isEmpty)?n+' is required':null;
 void showMsg(String s,{bool error=false}){if(mounted)setState((){message=s;isError=error;});}
 String authError(String c){switch(c){case'email-already-in-use':return'This email is already registered. If you did not create it here, use Forgot password to recover access.';case'invalid-email':return'Enter a valid email.';case'weak-password':return'Password must be at least 6 characters.';case'invalid-credential':case'wrong-password':case'user-not-found':return'Incorrect email or password.';default:return'Authentication failed: '+c;}}
 Future<void> submit()async{
  if(!f.currentState!.validate())return;setState(()=>busy=true);
  try{final a=FirebaseAuth.instance;
   if(reg){
    final c=await a.createUserWithEmailAndPassword(email:email.text.trim(),password:pass.text);final u=c.user!;
    await u.updateDisplayName(name.text.trim());
    await FirebaseFirestore.instance.collection('portalUsers').doc(u.uid).set({'uid':u.uid,'email':email.text.trim().toLowerCase(),'displayName':name.text.trim(),'phone':phone.text.trim(),'provider':'password','createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    await u.sendEmailVerification();
    showMsg('Verification email sent to '+email.text.trim()+'. Check Inbox, Spam and Promotions. After opening the link, return here and tap “I have verified”.');
   }else{
    final c=await a.signInWithEmailAndPassword(email:email.text.trim(),password:pass.text);await c.user!.reload();
    if(!a.currentUser!.emailVerified){await c.user!.sendEmailVerification();await a.signOut();showMsg('Your email is not verified. A new verification link has been sent.',error:true);}else{nativeBridgePassword=pass.text;}
   }
  }on FirebaseAuthException catch(e){showMsg(authError(e.code),error:true);}catch(_){showMsg('Something went wrong. Please try again.',error:true);}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> verify()async{
  setState(()=>busy=true);try{final u=FirebaseAuth.instance.currentUser;if(u==null){showMsg('Please register again.',error:true);return;}await u.reload();if(!FirebaseAuth.instance.currentUser!.emailVerified)showMsg('Email is not verified yet. Open the latest link.',error:true);}
  catch(_){showMsg('Could not check verification.',error:true);}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> forgotPassword() async {
  final value = email.text.trim();
  if (value.isEmpty) {
    showMsg('Enter your email address first, then tap Forgot password.', error: true);
    return;
  }
  setState(() => busy = true);
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
    showMsg('Password reset email sent to '+value+'. Check Inbox, Spam and Promotions.');
  } on FirebaseAuthException catch (e) {
    showMsg(authError(e.code), error: true);
  } catch (_) {
    showMsg('Could not send the reset email. Please try again.', error: true);
  } finally {
    if (mounted) setState(() => busy = false);
  }
 }
 @override
Widget build(BuildContext c) {
  return Scaffold(
    backgroundColor: const Color(0xFFFAF6EE),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: f,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(radius: 28, backgroundColor: Color(0xFF0D3B3E),
                        child: Text('C', style: TextStyle(color: Color(0xFFEAD39B), fontSize: 22, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 16),
                      Text(reg ? 'Create your account' : 'CMA MCQ Portal',
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF082627))),
                      const SizedBox(height: 6),
                      Text(reg ? 'Register inside the app. We will verify your email.' : 'Login securely with your verified email and password.',
                        style: const TextStyle(color: Color(0xFF65716F))),
                      const SizedBox(height: 20),
                      if (reg) ...[
                        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()), validator: (v) => req(v, 'Name')),
                        const SizedBox(height: 12),
                        TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()), validator: (v) => req(v, 'Phone number')),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => req(v, 'Email')),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pass, obscureText: hide,
                        decoration: InputDecoration(labelText: 'Password', border: const OutlineInputBorder(),
                          suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off))),
                        validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      if (reg) ...[
                        const SizedBox(height: 12),
                        TextFormField(controller: confirm, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                          validator: (v) => v != pass.text ? 'Passwords do not match' : null),
                      ],
                      const SizedBox(height: 16),
                      if (message.isNotEmpty)
                        Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: isError ? const Color(0xFFFDECEA) : const Color(0xFFE6EFED), borderRadius: BorderRadius.circular(9)),
                          child: Text(message)),
                      if (!reg)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: busy ? null : forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (busy) ...[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('Please wait...'),
                              ] else
                                Text(reg ? 'Create account' : 'Login'),
                            ],
                          ),
                        ),
                      ),
                      if (reg && FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.emailVerified)
                        TextButton(onPressed: busy ? null : verify, child: const Text('I have verified my email')),
                      TextButton(onPressed: busy ? null : () => setState(() { reg = !reg; message = ''; isError = false; }),
                        child: Text(reg ? 'Already have an account? Login' : 'New user? Create an account')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

}
class Portal extends StatefulWidget{const Portal({super.key});@override State<Portal> createState()=>_PortalState();}
class _PortalState extends State<Portal>{
 late final WebViewController w;bool loading=true,error=false;
 static const fix=r'''(function(){try{var m=document.querySelector('meta[name="viewport"]');if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}m.content='width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no,viewport-fit=cover';document.body.style.margin='0';document.body.style.overflowX='hidden';}catch(e){}})();''';
 Future<String> bridge()async{
  final u=FirebaseAuth.instance.currentUser!;final token=await u.getIdToken(true);
  return '(function(){try{var e='+jsonEncode(u.email??'')+',p='+jsonEncode(nativeBridgePassword??'')+';window.__cmaNativeFirebaseIdToken='+jsonEncode(token)+';window.__cmaNativeUser={email:e,displayName:'+jsonEncode(u.displayName??'')+',uid:'+jsonEncode(u.uid)+'};if(e&&p&&window.firebase&&firebase.auth){firebase.auth().setPersistence(firebase.auth.Auth.Persistence.LOCAL).then(function(){return firebase.auth().signInWithEmailAndPassword(e,p);}).then(function(){window.__cmaNativeWebAuthReady=true;window.dispatchEvent(new Event("cmaNativeFirebaseReady"));}).catch(function(err){console.error("TEST-02 web auth bridge",err);window.dispatchEvent(new Event("cmaNativeFirebaseReady"));});}else{window.dispatchEvent(new Event("cmaNativeFirebaseReady"));}}catch(e){console.error(e);}})();';
 }
 @override void initState(){super.initState();w=WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setUserAgent('CMA-MCQ-Portal-Android/4.0')..setBackgroundColor(const Color(0xFFFAF6EE))..setNavigationDelegate(NavigationDelegate(
  onPageStarted:(_){if(mounted)setState((){loading=true;error=false;});},
  onPageFinished:(url)async{await w.runJavaScript(fix);final u=Uri.tryParse(url);if(u?.host=='rohitfcg123-arch.github.io')await w.runJavaScript(await bridge());if(mounted)setState(()=>loading=false);},
  onWebResourceError:(e){if((e.isForMainFrame??false)&&mounted)setState((){loading=false;error=true;});},
  onNavigationRequest:(r)async{
    final u=Uri.tryParse(r.url);if(u==null)return NavigationDecision.prevent;
    if(u.scheme=='http'||u.scheme=='https')return NavigationDecision.navigate;
    // TEST-03: allow UPI deep links to leave the WebView and open an installed UPI app.
    if(u.scheme=='upi'||u.scheme=='intent'){
      try{
        final ok=await launchUrl(u,mode:LaunchMode.externalApplication);
        if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No UPI app could be opened. Please install/enable a UPI app and try again.')));
      }catch(e){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not open the UPI app. Please try again.')));
      }
    }
    return NavigationDecision.prevent;
  }))..loadRequest(Uri.parse(portalUrl));}
 Future<void> reload()async{setState((){loading=true;error=false;});await w.loadRequest(Uri.parse(portalUrl));}
 @override Widget build(BuildContext c)=>PopScope(canPop:false,onPopInvokedWithResult:(didPop,_)async{if(didPop)return;if(await w.canGoBack())await w.goBack();else if(mounted)Navigator.of(c).pop();},child:Scaffold(body:SafeArea(child:Stack(children:[WebViewWidget(controller:w),if(loading)const Align(alignment:Alignment.topCenter,child:LinearProgressIndicator(minHeight:2)),if(error)Center(child:FilledButton(onPressed:reload,child:const Text('Retry')))]))));
}
