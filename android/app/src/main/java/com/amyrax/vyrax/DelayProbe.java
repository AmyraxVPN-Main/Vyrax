package com.amyrax.vyrax;

import android.os.SystemClock;
import java.io.IOException;
import java.net.Proxy;
import java.util.concurrent.TimeUnit;
import okhttp3.ConnectionPool;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/** An authenticated URL test, with a warm second HEAD like unified delay. */
final class DelayProbe {
    static Long measure(Proxy proxy,String url,int timeoutMillis){
        long deadline=SystemClock.elapsedRealtime()+timeoutMillis;
        ConnectionPool pool=new ConnectionPool(1,10,TimeUnit.SECONDS);
        OkHttpClient client=new OkHttpClient.Builder().proxy(proxy).connectionPool(pool)
            .followRedirects(false).followSslRedirects(false).retryOnConnectionFailure(false)
            .connectTimeout(timeoutMillis,TimeUnit.MILLISECONDS).readTimeout(timeoutMillis,TimeUnit.MILLISECONDS).build();
        Long latency=null;
        try{
            for(int attempt=0;attempt<2;attempt++){
                long remaining=deadline-SystemClock.elapsedRealtime();if(remaining<=0)break;
                okhttp3.Call call=client.newCall(new Request.Builder().url(url).head().build());
                call.timeout().timeout(remaining,TimeUnit.MILLISECONDS);
                long start=SystemClock.elapsedRealtimeNanos();
                try(Response response=call.execute()){
                    if(response.code()!=200&&response.code()!=204)break;
                    latency=Math.max(1,TimeUnit.NANOSECONDS.toMillis(SystemClock.elapsedRealtimeNanos()-start));
                }catch(IOException error){break;}
            }
            return latency;
        }finally{pool.evictAll();}
    }
}
