package com.amyrax.vyrax;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import java.io.File;
import java.io.FileOutputStream;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

final class SecureStore {
    private static final String ALIAS="vyrax-profile-key";
    private final AtomicFile file;
    SecureStore(Context context){file=new AtomicFile(new File(context.getFilesDir(),"profiles.enc"));}
    private SecretKey key()throws Exception{
        KeyStore store=KeyStore.getInstance("AndroidKeyStore");store.load(null);
        if(store.containsAlias(ALIAS))return (SecretKey)store.getKey(ALIAS,null);
        KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    synchronized JSONObject load()throws Exception{
        if(!file.getBaseFile().exists())return Jsons.obj("profiles",new org.json.JSONArray(),"subscriptions",new org.json.JSONArray(),"selectedId","","activeSourceId","","selectionMode","manual","settings",Preferences.normalize(null));
        byte[] bytes=file.readFully();if(bytes.length<29||bytes.length>8*1024*1024)throw new IllegalStateException("err.store");
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,bytes,0,12));
        return new JSONObject(new String(cipher.doFinal(bytes,12,bytes.length-12),java.nio.charset.StandardCharsets.UTF_8));
    }
    synchronized void save(JSONObject value)throws Exception{
        if(value.toString().length()>4*1024*1024)throw new IllegalArgumentException("err.tooBig");
        JSONObject saved=Jsons.copy(value);XrayConfig.put(saved,"settings",Preferences.normalize(saved.optJSONObject("settings")));
        org.json.JSONArray profiles=Jsons.array(saved,"profiles");if(profiles.length()>4096)throw new IllegalArgumentException("err.tooBig");
        for(int i=0;i<profiles.length();i++)XrayConfig.validate(profiles.getJSONObject(i));
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key());
        byte[] encrypted=cipher.doFinal(saved.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
        FileOutputStream output=null;
        try{output=file.startWrite();output.write(cipher.getIV());output.write(encrypted);file.finishWrite(output);}catch(Exception error){if(output!=null)file.failWrite(output);throw error;}
    }
}
