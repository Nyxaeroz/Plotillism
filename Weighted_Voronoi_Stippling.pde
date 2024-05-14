// PARAMETERS FOR IMAGE
PImage input;
String input_name = "moonpool\\moonpool_small.png";
int canvas_w = 400; // Width of the canvas
int canvas_h = 400; // Height of the canvas

// PARAMETERS FOR STIPPLING
int N = 500; // Number of seed points
int thresh = 100;
int max_iter = 50;

// PARAMETERS FOR DEBUGGING
boolean show_paths = true;
boolean show_diagrams = false;
boolean preview_only = false;
boolean print_logs = false;
boolean show_img = true;

// PARAMETERS FOR PLOTTING
boolean save_hpgl = false;
String output_name = "output.txt";
int scale_offset = 500; // offset to scaling factor: max(w,h) + offset will occupy the short side off the paper
int longest_side = max(canvas_w, canvas_h) + scale_offset;
int plot_w = 500; // currently unused -- might be used for plotter coordinates
int ploth = 500; // currently unused -- might be used for plotter coordinates
int plot_offset_x = 0; // currently unused -- might be used for offsetting the output relative to a different starting point
int plot_offset_y = 0; // currently unused -- might be used for offsetting the output relative to a different starting point
PrintWriter hpgl_writer;

// VARIABLES YOU DON'T NEED TO TOUCH
PVector[] seeds = new PVector[N]; // Array to store seed points
float[] weights = new float[N]; // Array to store weights of seed points
int[][] colors = new int[canvas_w][canvas_h];


void setup() {
  // CANVAS SIZE -- CHANGE THIS TO THE SIZE OF YOUR IMAGE
  size(400, 400);
  
  // load and show input
  input = loadImage(sketchPath() + "\\" + input_name);
  image(input, 0, 0);
  
  // initialize seeds and voronoi diagram
  generate_seeds();
  show_seeds(color(255, 0, 0));
  generate_voronoi();
  
  // don't start relaxation if preview_only flag is set
  if (preview_only) { 
    noLoop(); 
  }
}

// draw loop
// is used for the relaxation of the original seed points
int iter = 0;
void draw() {
  if(iter==0) { delay(1000); }
  
  if (iter < max_iter) {
    println("Relaxing seed points, iteration", iter);
    update_seeds();
    generate_voronoi();
    
    if (show_diagrams) { show_voronoi(); }
    if (show_paths) { show_seeds(color(0,255-iter,iter)); }
    iter+=1;
  } else {
    noLoop();
    if (show_img) { image(input, 0, 0); }
    show_seeds(color(255, 0, 0));
    if (save_hpgl) { create_hpgl(); }
  }
  
}

// function for generating seed points
// generates N seed points chosen stochastically based on thresh
void generate_seeds() {
  if (print_logs) { println("generating", N, "seed points!"); }
  
  for (int i = 0; i < N; i++) {
    float rx = random(canvas_w);
    float ry = random(canvas_h);
    if (random(thresh) > brightness(input.get((int) rx, (int) ry))) {
      seeds[i] = new PVector(rx, ry);
    } else { i--; } // <-- don't do this at home
    
  }
}

// function for generating the voronoi diagram for the current set of seed points
// loops over all pixels and assigns a 'color' to them: the index of the seed point they're closest to
//     This is a very naive way of going about doing this, and has O(WIDTH * HEIGHT * N) complexity.
//     A heuristic might be applied: if a pixel P is closest to seed point S, any of P's neighbouring pixels are likely to be closest to S, too
//     Alternatively, there are optimized algorithms based on the Delaunay triangulation (the Voronoi's dual graph) that might be used here
void generate_voronoi() {
  if (print_logs) { println("generating voronoi diagram!"); }
  
  for (int y = 0; y < canvas_h; y++) {
    for (int x = 0; x < canvas_w; x++) {
      float min_dist = dist(x, y, seeds[0].x, seeds[0].y);
      int min_index = 0;
      
      // Find the nearest seed point
      for (int i = 1; i < N; i++) {
        float d = dist(x, y, seeds[i].x, seeds[i].y);
        if (d < min_dist) {
          min_dist = d;
          min_index = i;
        }
      }      
      colors[x][y] = min_index;
    }
  }
}

void update_seeds() {
  if (print_logs) { println("updating seedpoints!"); }
  
  for (int i = 0; i < N; i++) {
   weights[i] = 0;
   seeds[i].x = 0;
   seeds[i].y = 0;
   for (int y = 0; y < canvas_h; y++) {
     for (int x = 0; x < canvas_w; x++) {
       // check if colors[x][y] matches i
       // if not: skip
       if (colors[x][y] == i) {
         // if yes: calculate weight based on pixel value and move seedpoint
         float w = 1 - brightness(input.get(x,y)) / 255;
         seeds[i].x += x * w;
         seeds[i].y += y * w;
         weights[i] += w;
       }  
     }
   }  
 }
  
  
  for (int i = 0; i < N; i++) {
    seeds[i].x /= weights[i];
    seeds[i].y /= weights[i];
  }
}

void show_seeds(color c) {
  if (print_logs) { println("showing seeds!"); }
  
  for (int i = 0; i < N; i++) {
    stroke(c);
    circle(seeds[i].x, seeds[i].y, 1);
  }
}

void show_voronoi() {
  if (print_logs) { println("showing voronoi diagram!"); }
  
  loadPixels();
  for (int y = 0; y < canvas_h; y++) {
    for (int x = 0; x < canvas_w; x++) {
    pixels[y * canvas_w + x] = color ( colors[x][y] % 255 );
    }
  }
  updatePixels();
}

import java.util.Arrays;
import java.util.Comparator;

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//INSPIRED BY quark AT https://forum.processing.org/two/discussion/19469/sort-a-pvector-array.html
static final Comparator<PVector> VEC_CMP = new Comparator<PVector>() {
  @Override final int compare(final PVector a, final PVector b) {
    int cmp;
    return (cmp = Float.compare(a.y, b.y)) != 0 ? cmp : Float.compare(a.x, b.x);
  }
};
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

void create_hpgl () {
  Arrays.sort(seeds, VEC_CMP);
  String init_txt = 
  "IN;" +
  //"IP" + canvas_w + "," + canvas_h + ";" + // plotter coordinates: IP P1 P2
  "SC0,-" + longest_side + ",0," + longest_side / sqrt(2) + ";" + // user coordinates: SC U1 U2, where U1 maps to P1 and U2 to P2
  "SP1;";
  
  hpgl_writer = createWriter(sketchPath() + "\\" + output_name);
  hpgl_writer.println(init_txt);
  
  for (int i = 0; i < N; i++) {
    String stip_txt = "PA" + seeds[i].x + "," + seeds[i].y + ";PD;PU;";
    hpgl_writer.println(stip_txt);
  }
  
  hpgl_writer.flush();
  hpgl_writer.close();
  
}
