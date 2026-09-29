import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const questionUploaderAdmin = 'rohit.fcg123@gmail.com';

class QuestionUploaderPage extends StatefulWidget {
  const QuestionUploaderPage({super.key});
  @override State<QuestionUploaderPage> createState() => _QuestionUploaderPageState();
}

class _QuestionUploaderPageState extends State<QuestionUploaderPage> {
  final search = TextEditingController();
  final json = TextEditingController();
  final marks = TextEditingController();
  String group = '', subject = '', attempt = '', chapter = '', message = '';
  bool loading = true, answersOnly = false;
  List<Map<String,dynamic>> rows = [];
  final selected = <String>{};

  static const groups = {
    'foundation':'CMA Foundation','inter1':'CMA Intermediate Group 1',
    'inter2':'CMA Intermediate Group 2','final3':'CMA Final Group 3',
    'final4':'CMA Final Group 4'
  };

  @override void initState() {
    super.initState();
    load();
    search.addListener(() => setState(() {}));
  }

  @override void dispose() {
    search.dispose(); json.dispose(); marks.dispose(); super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('subjectiveQuestions').get();
      rows = snap.docs.map((d) => <String,dynamic>{'id':d.id,...d.data()}).toList();
      rows.sort((a,b) => (a['attempt']??'').toString().compareTo((b['attempt']??'').toString()));
      if (mounted) setState(() { loading=false; });
    } catch(e) {
      if (mounted) setState(() { loading=false; message='Load failed: '+e.toString(); });
    }
  }

  List<String> answers(Map<String,dynamic> x) {
    final out=<String>[];
    if(x['solutionHtmls'] is List) out.addAll((x['solutionHtmls'] as List).map((e)=>e.toString()));
    final one=(x['solutionHtml']??'').toString().trim();
    if(one.isNotEmpty) out.add(one);
    return out.toSet().toList();
  }

  List<String> unique(String field) {
    final v=rows.where((x)=>group.isEmpty||(x['group']??'')==group)
      .where((x)=>subject.isEmpty||(x['subject']??'')==subject)
      .where((x)=>attempt.isEmpty||(x['attempt']??'')==attempt)
      .map((x)=>(x[field]??'').toString()).where((x)=>x.isNotEmpty).toSet().toList();
    v.sort(); return v;
  }

  List<Map<String,dynamic>> get visible => rows.where((x) {
    if(group.isNotEmpty && (x['group']??'')!=group) return false;
    if(subject.isNotEmpty && (x['subject']??'')!=subject) return false;
    if(attempt.isNotEmpty && (x['attempt']??'')!=attempt) return false;
    if(chapter.isNotEmpty && (x['chapter']??'')!=chapter) return false;
    if(answersOnly && answers(x).isEmpty) return false;
    final q=search.text.trim().toLowerCase();
    if(q.isNotEmpty && ![x['id'],x['q'],x['html'],x['subject'],x['chapter'],x['attempt'],...answers(x)].join(' ').toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  String plain(String v) => v.replaceAll(RegExp(r'<[^>]+>'),' ').replaceAll('&nbsp;',' ').trim();

  String key(Map<String,dynamic> x) =>
      [x['group'],x['subject'],x['attempt'],x['q']].map((v)=>(v??'').toString().trim().toLowerCase()).join('|');

  Future<void> edit([Map<String,dynamic>? row]) async {
    final fresh=row==null;
    final c={
      'group':TextEditingController(text:(row?['group']??'final3').toString()),
      'subject':TextEditingController(text:(row?['subject']??'').toString()),
      'chapter':TextEditingController(text:(row?['chapter']??'').toString()),
      'attempt':TextEditingController(text:(row?['attempt']??'December 2025').toString()),
      'q':TextEditingController(text:(row?['q']??'').toString()),
      'marks':TextEditingController(text:row?['marks']==null?'':row!['marks'].toString()),
      'html':TextEditingController(text:(row?['html']??'').toString()),
      'solution':TextEditingController(text:(row?['solutionHtml']??'').toString()),
    };
    await showDialog(context:context,builder:(dc)=>AlertDialog(
      title:Text(fresh?'Upload New Question':'Edit Question / Answer'),
      content:SizedBox(width:650,child:SingleChildScrollView(child:Column(children:[
        DropdownButtonFormField<String>(value:groups.containsKey(c['group']!.text)?c['group']!.text:'final3',
          decoration:const InputDecoration(labelText:'Group'),items:groups.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
          onChanged:(v)=>c['group']!.text=v??'final3'),
        const SizedBox(height:8), TextField(controller:c['subject'],decoration:const InputDecoration(labelText:'Subject')),
        const SizedBox(height:8), TextField(controller:c['chapter'],decoration:const InputDecoration(labelText:'Chapter / Topic')),
        const SizedBox(height:8), TextField(controller:c['attempt'],decoration:const InputDecoration(labelText:'Attempt')),
        const SizedBox(height:8), Row(children:[
          Expanded(child:TextField(controller:c['q'],decoration:const InputDecoration(labelText:'Question Number'))),
          const SizedBox(width:8), Expanded(child:TextField(controller:c['marks'],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Marks')))
        ]),
        const SizedBox(height:8), TextField(controller:c['html'],minLines:7,maxLines:14,decoration:const InputDecoration(labelText:'Question HTML',border:OutlineInputBorder())),
        const SizedBox(height:8), TextField(controller:c['solution'],minLines:5,maxLines:12,decoration:const InputDecoration(labelText:'Suggested Answer HTML',border:OutlineInputBorder())),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('Cancel')),
        FilledButton(onPressed:() async {
          if(c['subject']!.text.trim().isEmpty||c['chapter']!.text.trim().isEmpty||c['q']!.text.trim().isEmpty||c['html']!.text.trim().isEmpty){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Subject, Chapter, Question No. and HTML are required.'))); return;
          }
          final data=<String,dynamic>{
            'group':c['group']!.text.trim(),'subject':c['subject']!.text.trim(),'chapter':c['chapter']!.text.trim(),
            'attempt':c['attempt']!.text.trim(),'q':c['q']!.text.trim(),
            'marks':c['marks']!.text.trim().isEmpty?null:int.tryParse(c['marks']!.text.trim()),
            'html':c['html']!.text,'solutionHtml':c['solution']!.text.trim(),
            'solutionHtmls':c['solution']!.text.trim().isEmpty?<String>[]:[c['solution']!.text.trim()],
            'updatedAt':FieldValue.serverTimestamp(),'updatedBy':questionUploaderAdmin
          };
          try{
            if(fresh){
              if(rows.any((x)=>key(x)==key(data))){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Duplicate question already exists.')));return;}
              await FirebaseFirestore.instance.collection('subjectiveQuestions').add(data);
            }else{
              await FirebaseFirestore.instance.collection('subjectiveQuestions').doc(row!['id'].toString()).set(data,SetOptions(merge:true));
            }
            if(dc.mounted)Navigator.pop(dc); await load();
          }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Save failed: '+e.toString())));}
        },child:Text(fresh?'Upload Question':'Save Changes'))
      ],
    ));
    for(final x in c.values)x.dispose();
  }

  Future<void> importJson() async {
    try{
      final p=jsonDecode(json.text.trim());
      final items=p is List?p:(p is Map&&p['questions'] is List?p['questions']:p is Map&&p['rows'] is List?p['rows']:p is Map&&p['data'] is List?p['data']:null);
      if(items is! List)throw Exception('JSON must be an array or contain questions[], rows[] or data[].');
      final snap=await FirebaseFirestore.instance.collection('subjectiveQuestions').get();
      final existing=<String,String>{for(final d in snap.docs)key({...d.data()}):d.id};
      final incoming=<Map<String,dynamic>>[];
      for(final z in items){
        if(z is! Map)continue;
        final x=Map<String,dynamic>.from(z);
        for(final k in ['group','subject','chapter','attempt','q','html'])if((x[k]??'').toString().trim().isEmpty)throw Exception('Missing required field: '+k);
        x['updatedAt']=FieldValue.serverTimestamp();x['updatedBy']=questionUploaderAdmin;
        incoming.add(x);
      }
      var replaced=0,added=0;
      for(var i=0;i<incoming.length;i+=450){
        final b=FirebaseFirestore.instance.batch();
        for(final x in incoming.skip(i).take(450)){
          final id=existing[key(x)];
          final ref=id==null?FirebaseFirestore.instance.collection('subjectiveQuestions').doc():FirebaseFirestore.instance.collection('subjectiveQuestions').doc(id);
          b.set(ref,x,SetOptions(merge:id!=null)); if(id==null)added++;else replaced++;
        }
        await b.commit();
      }
      json.clear();message='JSON complete: '+added.toString()+' added, '+replaced.toString()+' replaced.';await load();if(mounted)setState((){});
    }catch(e){if(mounted)setState(()=>message='Import failed: '+e.toString());}
  }

  Future<void> savePending() async {
    final value=int.tryParse(marks.text.trim());
    if(value==null||selected.isEmpty){setState(()=>message='Select questions and enter marks.');return;}
    for(var i=0;i<selected.length;i+=450){
      final b=FirebaseFirestore.instance.batch();
      for(final id in selected.skip(i).take(450))b.update(FirebaseFirestore.instance.collection('subjectiveQuestions').doc(id),{
        'pendingMarks':value,'marksApprovalStatus':'pending','marksRequestedBy':questionUploaderAdmin,
        'marksRequestedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),'updatedBy':questionUploaderAdmin});
      await b.commit();
    }
    message='Pending marks saved for '+selected.length.toString()+' question(s).';await load();if(mounted)setState((){});
  }

  Future<void> approveMarks() async {
    for(var i=0;i<selected.length;i+=450){
      final b=FirebaseFirestore.instance.batch();
      for(final id in selected.skip(i).take(450)){
        final x=rows.firstWhere((r)=>r['id']==id,orElse:()=>{});
        if(x['pendingMarks']==null)continue;
        b.update(FirebaseFirestore.instance.collection('subjectiveQuestions').doc(id),{
          'marks':x['pendingMarks'],'pendingMarks':FieldValue.delete(),'marksApprovalStatus':'approved',
          'marksApprovedBy':questionUploaderAdmin,'marksApprovedAt':FieldValue.serverTimestamp(),
          'updatedAt':FieldValue.serverTimestamp(),'updatedBy':questionUploaderAdmin});
      }
      await b.commit();
    }
    selected.clear();message='Pending marks approved.';await load();if(mounted)setState((){});
  }

  @override Widget build(BuildContext context){
    final list=visible,subjects=unique('subject'),attempts=unique('attempt'),chapters=unique('chapter');
    return Scaffold(
      appBar:AppBar(title:const Text('Question Uploader'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('New Question')),
      body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(12,12,12,100),children:[
        Card(child:Padding(padding:const EdgeInsets.all(12),child:const Text('UPDATE #196 — Question Uploader is now a native page inside the Admin app. It uses the same Firestore subjectiveQuestions data; no browser redirect is used.',style:TextStyle(fontWeight:FontWeight.w700))),),
        const SizedBox(height:8),
        if(message.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:8),child:Text(message)),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          const Align(alignment:Alignment.centerLeft,child:Text('Find / Manage Questions',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
          const SizedBox(height:8),TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search question, answer, ID, chapter...',border:OutlineInputBorder())),
          const SizedBox(height:8), select('Group',group,{'':'All Groups',...groups},(v)=>setState((){group=v;subject='';attempt='';chapter='';})),
          select('Subject',subject,{'':'All Subjects',for(final x in subjects)x:x},(v)=>setState((){subject=v;attempt='';chapter='';})),
          select('Attempt',attempt,{'':'All Attempts',for(final x in attempts)x:x},(v)=>setState((){attempt=v;chapter='';})),
          select('Chapter / Topic',chapter,{'':'All Chapters / Topics',for(final x in chapters)x:x},(v)=>setState(()=>chapter=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,value:answersOnly,onChanged:(v)=>setState(()=>answersOnly=v),title:const Text('Show Answers Only')),
          Row(children:[Expanded(child:Text(list.length.toString()+' question(s)')),TextButton(onPressed:()=>setState((){group='';subject='';attempt='';chapter='';answersOnly=false;search.clear();}),child:const Text('Clear'))])
        ]))),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          const Align(alignment:Alignment.centerLeft,child:Text('JSON Upload / Backup',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
          const SizedBox(height:6),TextField(controller:json,minLines:5,maxLines:10,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Paste Question JSON here...')),
          const SizedBox(height:8),FilledButton.icon(onPressed:importJson,icon:const Icon(Icons.upload_file),label:const Text('Import Questions JSON'))
        ]))),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          Row(children:[const Expanded(child:Text('Bulk Marks',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),Text(selected.length.toString()+' selected')]),
          const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:marks,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Marks',border:OutlineInputBorder()))),const SizedBox(width:6),FilledButton(onPressed:savePending,child:const Text('Save Pending')),const SizedBox(width:6),OutlinedButton(onPressed:approveMarks,child:const Text('Approve'))])
        ]))),
        if(list.isNotEmpty)Row(children:[
          Checkbox(value:list.every((x)=>selected.contains(x['id'].toString())),onChanged:(v)=>setState((){if(v==true){selected.addAll(list.map((x)=>x['id'].toString()));}else{selected.removeAll(list.map((x)=>x['id'].toString()));}})),
          const Text('Select all visible')
        ]),
        ...list.map((x)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(
          leading:Checkbox(value:selected.contains(x['id'].toString()),onChanged:(v)=>setState((){if(v==true){selected.add(x['id'].toString());}else{selected.remove(x['id'].toString());}})),
          title:Text((x['attempt']??'').toString()+' • Q'+(x['q']??'').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((x['subject']??'').toString()+' • '+(x['chapter']??'').toString()),
            if(x['marks']!=null)Text('Approved Marks: '+x['marks'].toString()),
            if(x['pendingMarks']!=null)Text('Pending Marks: '+x['pendingMarks'].toString(),style:const TextStyle(color:Color(0xFFC8A24A),fontWeight:FontWeight.w800)),
            const SizedBox(height:4),Text(plain((x['html']??'').toString()),maxLines:4,overflow:TextOverflow.ellipsis),
            if(answers(x).isNotEmpty)Text('✓ Suggested Answer ('+answers(x).length.toString()+' version(s))',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w700))
          ]),onTap:()=>edit(x),trailing:IconButton(onPressed:()=>edit(x),icon:const Icon(Icons.edit_outlined))
        )))
      ]))
    );
  }

  Widget select(String label,String value,Map<String,String> items,ValueChanged<String> onChanged)=>Padding(
    padding:const EdgeInsets.only(bottom:8),child:DropdownButtonFormField<String>(
      value:items.containsKey(value)?value:null,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      items:items.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>onChanged(v??'')
    ));
}
