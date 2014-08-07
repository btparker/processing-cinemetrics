import gab.opencv.*;
import org.opencv.core.Mat;

import processing.video.*;

boolean SEPARATE_SHOTS = true;
int SIG_DIG = 4;

PrintWriter output;

PImage currentFrame;
PImage previousFrame;

OpenCV currOpencv, prevOpencv;
Histogram prevGrayHist, prevRHist, prevGHist, prevBHist;
Histogram currGrayHist, currRHist, currGHist, currBHist;

PImage currEdges, prevEdges;

float _ecrWeight = 0.3;
float _histDiffWeight = 0.5;
float _sadWeight = 0.2;

float _ecrThresh = 0.2;
float _histDiffThresh = 15.0;
float _sadThresh = 0.2;
final int SHOT_COOLDOWN = 15;
int _shotFrame = 0;
int _shotIndex = 0;


int WIDTH = 640;
int HEIGHT = 360;
int frameIndex = 0;
int endFrame = 0;

String dataFolder = "data/";
String framesFolder = "frames/";


String separatedShots = dataFolder+"sep_shots/";



void setup() {
  // we'll have a look in the data folder
  java.io.File folder = new java.io.File(dataPath(framesFolder));
 
  // this is the filter (returns true if file's extension is .jpg)
  java.io.FilenameFilter jpgFilter = new java.io.FilenameFilter() {
    public boolean accept(File dir, String name) {
      return name.toLowerCase().endsWith(".jpg");
    }
  };
  // list the files in the data folder, passing the filter as parameter
  String[] filenames = folder.list(jpgFilter);
 
  // get and display the number of jpg files
  println(filenames.length + " jpg files in specified directory");

  endFrame = (filenames.length-1);

  String currFile = dataFolder+framesFolder+nf(0,SIG_DIG).toString()+".jpg";
  currentFrame = loadImage(currFile);
  WIDTH = currentFrame.width;
  HEIGHT = currentFrame.height;
  size(WIDTH, HEIGHT);
  currOpencv = new OpenCV(this, WIDTH, HEIGHT);
  prevOpencv = new OpenCV(this, WIDTH, HEIGHT);
  
  currentFrame = new PImage(WIDTH,HEIGHT);
  previousFrame = new PImage(WIDTH,HEIGHT);
  
  currEdges = new PImage(WIDTH, HEIGHT);
  
  output = createWriter(dataFolder+"video_shots.txt"); 
}

void draw() {
  String currFile = dataFolder+framesFolder+nf(frameIndex,SIG_DIG).toString()+".jpg";
  currentFrame = loadImage(currFile);
  image(currentFrame,0,0);
  if(frameIndex > 0 && frameIndex <= endFrame){
    String prevFile = dataFolder+framesFolder+nf(frameIndex-1,SIG_DIG).toString()+".jpg";
    previousFrame = loadImage(prevFile);
    
    float histDiffs = histogramDifferences();
    float ecr = edgeChangeRatio();
    float sad = SAD(currentFrame, previousFrame);
    
    float histDiffsDetected = map(histDiffs,0,_histDiffThresh,0.0,1.0);
    histDiffsDetected = histDiffsDetected < 0 ? 0 : histDiffsDetected;
    
    float ecrDetected = map(ecr,0,_ecrThresh,0.0,1.0);
    ecrDetected = ecrDetected < 0 ? 0 : ecrDetected;
    
    float sadDetected = map(sad,0,_sadThresh,0.0,1.0);
    sadDetected = sadDetected < 0 ? 0 : sadDetected;

    float shotProbability = _histDiffWeight*histDiffsDetected+_ecrWeight*ecrDetected+_sadWeight*sadDetected;
    
    boolean shotDetected = shotProbability >= 1.0;
    
    if(shotDetected && _shotFrame > SHOT_COOLDOWN){
      
      println("Shot "+_shotIndex +" detected at frame " + frameIndex);
      
      output.println(_shotIndex + " START " +(frameIndex-_shotFrame)+" END " + frameIndex);
      _shotIndex++;
      _shotFrame = 0;
    }
    if(SEPARATE_SHOTS){
      saveFrame(separatedShots+_shotIndex+"/"+nf(frameIndex,SIG_DIG).toString()+".jpg");
    }
    
    
  }
  
  if(frameIndex >= endFrame){
    output.println(_shotIndex + " START " +(frameIndex-_shotFrame)+" END " + frameIndex);
    output.flush(); // Writes the remaining data to the file
    output.close(); // Finishes the file
    if(SEPARATE_SHOTS){
      saveFrame(separatedShots+_shotIndex+"/"+nf(frameIndex,SIG_DIG).toString()+".jpg");
    }
    noLoop();
  }
  
  _shotFrame++;
  frameIndex++;
}

float histogramDifferences(){
    currOpencv.loadImage(currentFrame);
    currGrayHist = currOpencv.findHistogram(currOpencv.getGray(), 256);
    currRHist = currOpencv.findHistogram(currOpencv.getR(), 256);
    currGHist = currOpencv.findHistogram(currOpencv.getG(), 256);
    currBHist = currOpencv.findHistogram(currOpencv.getB(), 256);
    
    prevOpencv.loadImage(previousFrame);
    prevGrayHist = currOpencv.findHistogram(prevOpencv.getGray(), 256);
    prevRHist = prevOpencv.findHistogram(prevOpencv.getR(), 256);
    prevGHist = prevOpencv.findHistogram(prevOpencv.getG(), 256);
    prevBHist = prevOpencv.findHistogram(prevOpencv.getB(), 256);
    
    return histAbsDiff(currRHist, prevRHist)+histAbsDiff(currGHist, prevGHist)+histAbsDiff(currBHist, prevBHist);
}

float edgeChangeRatio(){
  currOpencv.loadImage(currentFrame);
  currOpencv.findCannyEdges(90,130);
  currOpencv.dilate();
  currOpencv.dilate();
  currEdges = currOpencv.getSnapshot();
  
  prevOpencv.loadImage(previousFrame);
  prevOpencv.findCannyEdges(90,130);
  prevOpencv.dilate();
  prevOpencv.dilate();
  prevEdges = prevOpencv.getSnapshot();
  
  float ecr = 0;
  currEdges.loadPixels();
  prevEdges.loadPixels();
  for(int i = 0; i < currEdges.pixels.length; i++){
    ecr += abs(brightness(currEdges.pixels[i]) - brightness(prevEdges.pixels[i]));
  }
  
  return (ecr/255)/(WIDTH*HEIGHT);
}

float histAbsDiff(Histogram a, Histogram b){
  Mat aMat = a.getMat();
  Mat bMat = b.getMat();
  int numBins = aMat.height();
  float histDiff = 0;
  for (int i  = 0; i < numBins; i++) {
    float va = (float)aMat.get(i, 0)[0];
    float vb = (float)bMat.get(i, 0)[0];
    histDiff += abs(va-vb);
  } 
  return histDiff;
}

int SSD(PImage a, PImage b){
  int ssd = 0;
  a.loadPixels();
  b.loadPixels();
  
  for(int i = 0; i < a.pixels.length; i++){
    int v = a.pixels[i] - b.pixels[i];
    ssd += v * v; 
  }
  
  return ssd;
}

float SAD(PImage a, PImage b){
  float sad = 0;
  a.loadPixels();
  b.loadPixels();
  
  for(int i = 0; i < a.pixels.length; i++){
    sad += abs(brightness(a.pixels[i]) - brightness(b.pixels[i]));
  }
  
  return (sad/255)/(WIDTH*HEIGHT);
}
