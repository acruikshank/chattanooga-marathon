package com.example.fftsample;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.Intent;
import android.widget.TextView;

import com.emotiv.insight.IEdk;
import com.emotiv.insight.IEdkErrorCode;
import com.emotiv.insight.IEdk.IEE_DataChannel_t;
import com.emotiv.insight.IEdk.IEE_Event_t;

public class MainActivity extends Activity {

	private static final int REQUEST_ENABLE_BT = 1;
	private BluetoothAdapter bluetoothAdapter;
	private boolean lock = false;
	private boolean isEnablGetData = false;
	private boolean isEnableWriteFile = false;
	int userId;
	private BufferedWriter motion_writer;
	Button Start_button;
    TextView Status_label;
	IEE_DataChannel_t[] Channel_list = {IEE_DataChannel_t.IED_AF3, IEE_DataChannel_t.IED_T7,IEE_DataChannel_t.IED_Pz,
			IEE_DataChannel_t.IED_T8,IEE_DataChannel_t.IED_AF4};
	String[] Name_Channel = {"AF3","T7","Pz","T8","AF4"};
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);
		
		final BluetoothManager bluetoothManager =
                (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        bluetoothAdapter = bluetoothManager.getAdapter();
        if (!bluetoothAdapter.isEnabled()) {
            if (!bluetoothAdapter.isEnabled()) {
                Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
            }
        }
		Start_button = (Button)findViewById(R.id.startbutton);
        Status_label = (TextView)findViewById(R.id.status);

		Start_button.setOnClickListener(new OnClickListener() {
			
			@Override
			public void onClick(View arg0) {
				// TODO Auto-generated method stub
				Log.e("FFTSample","Start Write File");
				setDataFile();
                if (isEnableWriteFile) {
                    isEnableWriteFile = false;
    				Log.e("FFTSample","Stop Write File");
	    			StopWriteFile();
                    Start_button.setText("Start Recording");
                } else {
                    isEnableWriteFile = true;
                    Start_button.setText("Stop Recording");
                }
			}
		});

		//Connect to emoEngine
		IEdk.IEE_EngineConnect(this,"");
		Thread processingThread=new Thread()
		{
			@Override
			public void run() {
				// TODO Auto-generated method stub
				super.run();
				while(true)
				{
					try
					{
						handler.sendEmptyMessage(0);
						handler.sendEmptyMessage(1);
						if(isEnablGetData && isEnableWriteFile)handler.sendEmptyMessage(2);
						Thread.sleep(250);
					}
					
					catch (Exception ex)
					{
						ex.printStackTrace();
					}
				}
			}
		};		
		processingThread.start();
	}
	
	Handler handler = new Handler() {
		@Override
		public void handleMessage(Message msg) {
			switch (msg.what) {

			case 0:
				int state = IEdk.IEE_EngineGetNextEvent();
				if (state == IEdkErrorCode.EDK_OK.ToInt()) {
					int eventType = IEdk.IEE_EmoEngineEventGetType();
				    userId = IEdk.IEE_EmoEngineEventGetUserId();
					if(eventType == IEE_Event_t.IEE_UserAdded.ToInt()){
						Log.e("FFTSample", "User added");
						IEdk.IEE_FFTSetWindowingType(userId, IEdk.IEE_WindowsType_t.IEE_BLACKMAN);
                        Status_label.setText("Emotive Connected");
						isEnablGetData = true;
					}
					if(eventType == IEE_Event_t.IEE_UserRemoved.ToInt()){
						Log.e("FFTSample","User removed");
                        Status_label.setText("Waiting for Emotive...");
						isEnablGetData = false;
					}
				}
				
				break;
			case 1:
				int number = IEdk.IEE_GetInsightDeviceCount();
				if(number != 0) {
					if(!lock){
						lock = true;
						IEdk.IEE_ConnectInsightDevice(0);
					}
				}
				else lock = false;
				break;
			case 2:
				float[] sample = new float[25];
				for(int i=0; i < Channel_list.length; i++)
				{
					double[] data = IEdk.IEE_GetAverageBandPowers(Channel_list[i]);
					if(data != null && data.length == 5){
						for (int j=0; j<5; j++)
							sample[i*5+j] = (float) data[j];
//						try {
//							motion_writer.write(Name_Channel[i] + ",");
//							for(int j=0; j < data.length;j++)
//								addData(data[j]);
//							motion_writer.newLine();
//						} catch (IOException e) {
//							// TODO Auto-generated catch block
//							e.printStackTrace();
//						}
					}
				}

                ConnectivityManager connMgr = (ConnectivityManager)
                        getSystemService(Context.CONNECTIVITY_SERVICE);
                NetworkInfo networkInfo = connMgr.getActiveNetworkInfo();
                if (networkInfo != null && networkInfo.isConnected()) {
                    ByteBuffer sampleBuffer = ByteBuffer.allocate(sample.length*4);
					sampleBuffer.order(ByteOrder.LITTLE_ENDIAN);
                    sampleBuffer.asFloatBuffer().put(sample);
                    new SendDataTask().execute(sampleBuffer);
                } else {
                    Log.e("FFTSample","No Connectivity");
                }
				break;
			}

		}

	};

    private class SendDataTask extends AsyncTask<ByteBuffer, Void, Void> {
        @Override
        protected Void doInBackground(ByteBuffer... sampleData) {

            try {
                URL url = new URL("http://chattanooga-marathon-alex.ngrok.io/api/samples");
                HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();
                try {
                    urlConnection.setDoOutput(true);
                    urlConnection.setChunkedStreamingMode(0);

                    OutputStream out = new BufferedOutputStream(urlConnection.getOutputStream());
                    out.write(sampleData[0].array(), 0, sampleData[0].capacity());
                    out.close();

                    InputStream in = new BufferedInputStream(urlConnection.getInputStream());
                    in.close();
                } finally {
                    urlConnection.disconnect();
                }
            } catch (IOException ioe) {
                ioe.printStackTrace();
            }
            return null;
        }

    }
	
	private void setDataFile() {
		try {
			String eeg_header = "Channel , Theta ,Alpha ,Low beta ,High beta , Gamma ";
			File root = Environment.getExternalStorageDirectory();
			String file_path = root.getAbsolutePath()+ "/FFTSample/";
			File folder=new File(file_path);
			if(!folder.exists())
			{
				folder.mkdirs();
			}		
			motion_writer = new BufferedWriter(new FileWriter(file_path+"bandpowerValue.csv"));
			motion_writer.write(eeg_header);
			motion_writer.newLine();
		} catch (Exception e) {
			Log.e("","Exception"+ e.getMessage());
		}
	}
	private void StopWriteFile(){
		try {
			motion_writer.flush();
			motion_writer.close();
		} catch (Exception e) {
			// TODO: handle exception
		}
	}
	/**
	 * public void addEEGData(Double[][] eegs) Add EEG Data for write int the
	 * EEG File
	 * 
	 * @param data
	 *            - double array of eeg data
	 */
//	public void addData(double data) {
//
//		if (motion_writer == null) {
//			return;
//		}
//
//		String input = "";
//		input += (String.valueOf(data) + ",");
//		try {
//			motion_writer.write(input);
//		} catch (IOException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//		}
//
//	}

}
