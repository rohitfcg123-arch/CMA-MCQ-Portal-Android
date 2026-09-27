/* CMA Portal — shared Firebase bootstrap */
(function(){
  'use strict';
  const firebaseConfig={
    apiKey:"AIzaSyCDQRVXCxHZfy3cLUJg2jG3kUTuBABHMbc",
    authDomain:"cma-mcq-portal-cf33f.firebaseapp.com",
    projectId:"cma-mcq-portal-cf33f",
    storageBucket:"cma-mcq-portal-cf33f.firebasestorage.app",
    messagingSenderId:"208738737302",
    appId:"1:208738737302:web:3754a55033f67a8ffef6b7",
    measurementId:"G-TXD74QQE8F"
  };
  if(!window.firebase) return;
  if(!firebase.apps.length) firebase.initializeApp(firebaseConfig);
  window.CMA_AUTH=window.CMA_AUTH||firebase.auth();
  window.CMA_DB=window.CMA_DB||firebase.firestore();
})();
