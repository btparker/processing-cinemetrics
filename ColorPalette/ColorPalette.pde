PImage frame;
String dataFolder = "data/";
String framesFolder = "frames/";
String outputFolder = "output/";
int SIG_DIG = 4;

int frameIndex = 0;
int endFrame = 0;
int WIDTH = 640;
int HEIGHT = 410;

int colorBandHeight = 50;
void setup(){
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
  frame = loadImage(currFile);
  frame = loadImage("data/frames/0000.jpg");
  size(WIDTH,HEIGHT);
  
  noStroke();
}

void draw(){
  background(127);
  image(frame,0,0);
  String currFile = dataFolder+framesFolder+nf(frameIndex,SIG_DIG).toString()+".jpg";
  frame = loadImage(currFile);
  frame.filter(POSTERIZE,16);
  IntDict frameColorPalette = colorPalette(frame, 10, 0.05);
  int[] frameColorPaletteValues = frameColorPalette.valueArray();
  String[] frameColorPaletteKeys = frameColorPalette.keyArray();
  int freqMin = min(frameColorPaletteValues);
  int freqMax = max(frameColorPaletteValues);
  int freqSum = 0;
  for(int i = 0; i < frameColorPaletteValues.length; i++){
    freqSum += frameColorPaletteValues[i];
  }
  
  
  int xOffset = 0;
  int yOffset = frame.height;
  int histSum = 0;
  for(int i = 0; i < frameColorPaletteValues.length; i++){
    int histWidth = round(map(frameColorPaletteValues[i],freqMin,freqMax,5.0,100));
    histSum += histWidth;
  }
  
  for(int i = 0; i < frameColorPaletteValues.length; i++){
    int histWidth = round(map(frameColorPaletteValues[i],freqMin,freqMax,5.0,100));
    histWidth = round(map(histWidth,0,histSum,0,600));
    fill(unhex(frameColorPaletteKeys[i]));
    
    if(i == frameColorPaletteValues.length-1){
      rect(xOffset,yOffset,WIDTH-xOffset,colorBandHeight);
    }
    else{
      rect(xOffset,yOffset,histWidth,colorBandHeight);
    }
    
    xOffset += histWidth;
  }
  saveFrame(dataFolder+outputFolder+nf(frameIndex,SIG_DIG).toString()+".jpg");
  if(frameIndex >= endFrame){
    frameIndex = 0;
  }
  frameIndex++;
}

IntDict colorPalette(PImage src, int maximum, float tolerance){
  IntDict indexedColors = new IntDict();
  String hexColor;
  src.loadPixels();
  for(int x = 0; x < src.width; x++){
    for(int y = 0; y < src.height; y++){
      int loc = x + y*src.width;
       hexColor = hex(src.pixels[loc]);
       if(indexedColors.hasKey(hexColor)){
        indexedColors.increment(hexColor); 
       }
       else{
         indexedColors.set(hexColor,1);
       }
    }
  }
  
  indexedColors.sortValuesReverse();
  String[] indexedColorsArray = indexedColors.keyArray();
  IntDict srcColorPalette = new IntDict();

  IntList uniqueColors = new IntList();
  
  for(int i = 0; i < indexedColors.size() && uniqueColors.size() < maximum; i++){
   if(different(color(unhex(indexedColorsArray[i])), uniqueColors, tolerance)){
     uniqueColors.append(color(unhex(indexedColorsArray[i]))); 
     srcColorPalette.set(indexedColorsArray[i],indexedColors.get(indexedColorsArray[i]));
   }
  }
  
  FloatDict luminence = new FloatDict();
  for(int i = 0; i < uniqueColors.size(); i++){
    luminence.set(hex(uniqueColors.get(i)), brightness(uniqueColors.get(i))+0.2126*red(uniqueColors.get(i)) + 0.7152*green(uniqueColors.get(i)) + 0.0722*blue(uniqueColors.get(i)));  
  }
    
  luminence.sortValuesReverse();
  
  IntDict orderedSrcColorPalette = new IntDict();
    
  String[] stringColors = luminence.keyArray();
  
  for(int i = 0; i < luminence.size(); i++){
    orderedSrcColorPalette.set(stringColors[i],srcColorPalette.get(stringColors[i]));
  }    
    
  return orderedSrcColorPalette;
}

boolean colorsSimilar(color c0, color c1, float toleranceIn){
  int tolerance = round(toleranceIn * ( 255 * 255 * 3 ))<< 0;
  
  float distance = 0;
  distance += pow(hue(c0)-hue(c1),2);
  distance += pow(saturation(c0)-saturation(c1),2);
  distance += pow(brightness(c0)-brightness(c1),2);
  
  return distance <= tolerance;
}

boolean different(color c0, IntList colors, float tolerance){
  for(int i = 0; i < colors.size(); i++){
    if(colorsSimilar(c0,colors.get(i),tolerance)){
      return false;  
    }
  }  
  return true;
}

IntList uniqueColors(color[] colors, int maximum, float tolerance){
  IntList uniqueColors = new IntList();
  
  for(int i = 0; i < colors.length && uniqueColors.size() < maximum; i++){
   if(different(colors[i], uniqueColors, tolerance)){
     uniqueColors.append(colors[i]); 
   }
  }
  
  return uniqueColors;
}

color[] sortByLuminance(IntList colors){
    FloatDict luminence = new FloatDict();
    for(int i = 0; i < colors.size(); i++){
      luminence.set(hex(colors.get(i)), 0.2126*red(colors.get(i)) + 0.7152*green(colors.get(i)) + 0.0722*blue(colors.get(i)));  
    }
    
    luminence.sortValuesReverse();
    
    String[] stringColors = luminence.keyArray();
    color[] indexedColors = new color[luminence.size()];
    for(int i = 0; i < luminence.size(); i++){
      indexedColors[i] = color(unhex(stringColors[i]));
    }    
    return indexedColors;
}

int scaleColorIndex(int i, int[] c) {
  return round((i / 255) * (c.length - 1));
}

void reduceColors(PImage src, int numColors){
  int[] rA = new int[256];
  int[] gA = new int[256];
  int[] bA = new int[256];
  
  int n = 256/(numColors/3);
  
  for(int i = 0; i < 256; i++){
    bA[i] = floor(i/n)*n;
    gA[i] = bA[i] << 8;
    rA[i] = gA[i] << 8;    
  }
  
  paletteMap(src, rA, gA, bA);
}

void paletteMap(PImage src, int[] rA, int[] gA, int[] bA){
    src.loadPixels();
    println(src.pixels.length);
    println(frame.width*frame.height);
    
    for(int i = 0; i < src.pixels.length; i++){
      int cr = floor(red(src.pixels[i]));
      int cg = floor(green(src.pixels[i]));
      int cb = floor(blue(src.pixels[i]));
      
      int r = rA[scaleColorIndex(cr,rA)];
      int g = gA[scaleColorIndex(cg,gA)];
      int b = bA[scaleColorIndex(cb,bA)];
      
      src.pixels[i] = color(r,g,b);
    }
    
    
    src.updatePixels();
}

color averageColorInROI(PImage img, int xstart, int ystart, int xend, int yend){
  img.loadPixels();
  float avgR = 0;
  float avgG = 0;
  float avgB = 0;
  // Begin our loop for every pixel
  for (int x = xstart; x < xend; x++) {
    for (int y = ystart; y < yend; y++ ) {
      int loc = x + y*img.width;
      avgR += red   (img.pixels[loc]);
      avgG += green (img.pixels[loc]);
      avgB += blue  (img.pixels[loc]);
    }
  }
  
  float roiSize = (xend-xstart)*(yend-ystart);
  avgR /= roiSize;
  avgG /= roiSize;
  avgB /= roiSize;
  return color(avgR,avgG,avgB);
}

color[][] getColorBinning(PImage img, int splitX, int splitY){
  int cols = splitX;
  int rows = splitY;
  int[][] colorBins = new int[cols][rows];
  
  int xstart, ystart, xend, yend = 0;
  int segmentW = constrain(ceil((img.width/(float)cols)),1,width);
  int segmentH = constrain(ceil((img.height/(float)rows)),1,height);
  
  for(int c = 0; c < cols; c++){
    for(int r = 0; r < rows; r++){
      xstart = constrain(c*segmentW,0,width);
      xend = constrain(xstart+segmentW,0,width);
      ystart = constrain(r*segmentH,0,height);
      yend = constrain(ystart+segmentH,0,height);
      colorBins[c][r] = averageColorInROI(img, xstart, ystart, xend, yend);
    }  
  }
  
  return colorBins;
}

void drawColorBins(int[][] colorBins){
  int cols = colorBins.length;
  int rows = colorBins[0].length;
  
  int xstart, ystart, xend, yend = 0;
  int segmentW = ceil((width/(float)cols));
  int segmentH = ceil((height/(float)rows));
  for(int c = 0; c < cols; c++){
    xstart = constrain(c*segmentW,0,width);
    xend = constrain(xstart+segmentW,0,width);
    for(int r = 0; r < rows; r++){
      ystart = constrain(r*segmentH,0,height);
      yend = constrain(ystart+segmentH,0,height);
      fill(colorBins[c][r]);
      rect(xstart, ystart, xend-xstart, yend-ystart);
    }  
    
  }
  println(width);
}
