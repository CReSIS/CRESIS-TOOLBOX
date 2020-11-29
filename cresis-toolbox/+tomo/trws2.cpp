// trws2.cpp
//
// Extract 3D surface of ice-bed layers
//
// Authors:
//  Mingze Xu, July 2016
//  Basic prior/unary cost, binary cost/weight, John Paden 2020
//  Traversal patterns, Debug Output, Skip Columns, Reece Mathews 2020
//
// See also: trws2.h
//
// mex -v -largeArrayDims trws2.cpp

#include <cmath>
#include <ctime>
#include <stddef.h>
using namespace std;
#include "mex.h"
#include "trws2.h"


void print_time(void)
{
  char time_str[256];
  time_t curr_time;
  tm *curr_tm;
  
  time(&curr_time);
  curr_tm = localtime(&curr_time);
  strftime(time_str,256,"%T",curr_tm);
  mexPrintf("%s\n", time_str);
  mexEvalString("keyboard;");
}


class TRWS {
public:
  // mNt: Fast-time dimension (number of rows/first-dimension in mImage)
  size_t mNt;
  // mNsv: Cross-track dimension (number of columns/second-dimension in mImage)
  size_t mNsv;
  // mNsv_center: Starting index of TRW-S iteration in cross-track dimension
  size_t mNsv_center;
  // mNx: Along-track dimension (number of range lines/third-dimension in mImage)
  size_t mNx;
  // mMax_Loops: Number of message passing loops/iterations to run
  const unsigned int mMax_Loops;
  // mImage: 3D mNt*mNsv*mNx mImage
  const float *mImage;
  // message_DIRECTION: mNt*mNsv*mNx message matrixes. These are like an inbox:
  // they represent messages sent from other nodes to the node with the
  // corresponding index.
  float *mMessage_Left; // Message or inbox from node to the left
  float *mMessage_Up; // Message or inbox from node above
  float *mMessage_Right; // Message or inbox from node to the right
  float *mMessage_Down; // Message or inbox from node below
  
  // mAT_Slope: along-track expected slope (should generally compensate for radar platform elevation changes)
  const float *mAT_Slope;
  // mAT_Weight: along-track binary/transition/slope weight
  const float *mAT_Weight;
  // mCT_Slope: cross-track binary/transition/slope coefficients (first row: range, second row: theta)
  const float *mCT_Slope;
  // mCT_Weight: cross-track binary/transition/slope weight
  const float *mCT_Weight;
  // mBounds: fast-time dimension bounds
  const unsigned int *mBounds;
  // mCT_Bounds_Right: cross-track dimension bounds, right
  const unsigned int *mCT_Bounds_Right;
  // mCT_Bounds_Left: cross-track dimension bounds, left
  const unsigned int *mCT_Bounds_Left;
  // mTraversal_Method: Value in range 0-2. 0: Original center-out traversal method. 1: 4 permutation traversal. 2: 2 perm optimized traversal
  const unsigned int mTraversal_Method;

  float *mResult;
  float *mDebug;
    
  TRWS(const float *image, const size_t *dim_image, const float *at_slope, const float *at_weight,
          const float *ct_slope, const float *ct_weight, const unsigned int max_loops,
          const unsigned int *bounds, const unsigned int traversal_method, 
          const unsigned int *ct_bounds_left, const unsigned int *ct_bounds_right, float *result, float *debug)
          : mImage(image), mAT_Slope(at_slope), mAT_Weight(at_weight), mCT_Slope(ct_slope), mCT_Weight(ct_weight),
            mMax_Loops(max_loops), mBounds(bounds), mTraversal_Method(traversal_method), mCT_Bounds_Left(ct_bounds_left), 
            mCT_Bounds_Right(ct_bounds_right), mResult(result), mDebug(debug) {
            // Set dimensions
            mNt  = dim_image[0];
            mNsv = dim_image[1];
            mNx  = dim_image[2];
            mNsv_center = round(mNsv/2);

            // Allocate message inboxes
            // calloc sets the values to zero which corresonds to floating point value of 0
            mMessage_Left = reinterpret_cast<float *>(calloc(mNt*mNsv*mNx,sizeof(float)));
            mMessage_Right = reinterpret_cast<float *>(calloc(mNt*mNsv*mNx,sizeof(float)));
            mMessage_Up = reinterpret_cast<float *>(calloc(mNt*mNsv*mNx,sizeof(float)));
            mMessage_Down = reinterpret_cast<float *>(calloc(mNt*mNsv*mNx,sizeof(float)));
          }
          
          ~TRWS() {
            free(mMessage_Left);
            free(mMessage_Right);
            free(mMessage_Up);
            free(mMessage_Down);
          }
          
          // Set mResult
          void set_result();
          // Extract surface
          void solve();
};

void TRWS::set_result() {
  
  size_t result_idx = 0;
  for (size_t w = 0; w < mNx; w++) {
    for (size_t h = 0; h < mNsv; h++) {
      float min_val = INFINITY;
      size_t best_result = mNx;
      for (size_t d = mBounds[2*w], message_idx = h*mNt + w*mNsv*mNt+mBounds[2*w]; d <= mBounds[2*w+1]; d++, message_idx++) {
        // Unary cost
        float temp = -mImage[message_idx];
        // Binary costs (up,down,left,right)
        temp += mMessage_Left[message_idx];
        temp += mMessage_Up[message_idx];
        temp += mMessage_Right[message_idx];
        temp += mMessage_Down[message_idx];

        if (mDebug) {
          mDebug[message_idx] = temp;
        }

        // Check to see if this d is the minimum
        if (temp < min_val) {
          min_val = temp;
          best_result = d;
        }
      }
      
      mResult[result_idx] = static_cast<int>(best_result+1);

      result_idx++;
    }
  }
}

void TRWS::solve() {
  // mNsvs_array: array of indices that allow iteration to go from the
  // midpoint outward
  //
  // Propagate h/mNsv from the midpoint out (mNsv_center) and let it be
  // biased by the current loop's mResults. This means the starting point
  // can have a large affect on the result because propagation away from
  // the starting point is much more effective and far reaching. In our
  // case, the midpoint always has ground truth so it is a good.
  float mNsvs_array[mNsv];
  for (int i=0; i<=mNsv_center; i++) {
    mNsvs_array[i] = mNsv_center-i; // From center to left
  }
  for (int i=mNsv_center+1; i<mNsv; i++) {
    mNsvs_array[i] = i; // From center to right
  }

  // Arrays for holding all the incoming messages. On each iteration, every
  // pixel sends out a message in all four directions (up/down in
  // cross-track and left/right in along-track) and this message is the sum
  // of the mImage/unary cost and all the input messages to this node except
  // the message that came from the direction that the message is going).
  float message_sum[mNt];
  float message_in[mNt];

  time_t start_time;
  time(&start_time);
  for (int loop = 0; loop < mMax_Loops; loop++) {
    if (loop > 0) {
      mexPrintf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b", loop);
      time_t curr_time;
      time(&curr_time);
      mexPrintf("  loop: %2d of %2d, time per loop: %5.0f seconds\n", loop+1, mMax_Loops, double(curr_time-start_time)/double(loop));
    } else {
      mexPrintf("  loop: %2d of %2d                              \n", loop+1, mMax_Loops);
    }

    bool odd_iteration = loop%2;
    // Loop through along-track dimension
    for (size_t w_idx = 0; w_idx < mNx; w_idx++) {
      size_t w;
      if (odd_iteration) {
        // Iterating right to left
        w = mNx-1-w_idx;
      } else {
        // Iterating left to right
        w = w_idx;
      }
      //mexPrintf("  w: %5d of %5d\n", w+1, mNx);
      // To allow the Matlab program to continue to take GUI inputs while
      // TRWS in running, call drawnow.
      mexEvalString("drawnow;");
      
      // Loop through cross-track dimension
      for (size_t h_idx = 0; h_idx < mNsv; h_idx++) {
        // Switch iteration direction every 2 loops
        size_t h = 0;
        bool backward = false;
        bool pass_all = true;

        if (mTraversal_Method == 0) {
          // Iterate from the center always 
          h = mNsvs_array[h_idx];

        } else {
          
          if (mTraversal_Method == 1) {
            // 4 iteration permutations. Only change inner traversal every two loops
            backward = (loop >> 1) % 2 == 0;

          } else if (mTraversal_Method == 2) {
            // 2 iteration permutations. Change inner traversal with outer.
            backward = odd_iteration;
            pass_all = false;
          }

          if (backward) {
            // Iterating bottom to top
            h = mNsv - 1 - h_idx;
          } else {
            // Iterating top to bottom
            h = h_idx;
          }
        }

        // Index to start of current range line in along-track/elevation angle in cross-track
        size_t cur_message_idx = (h + w*mNsv)*mNt;
        int cur_rbin_start = mBounds[2*w];
        int cur_rbin_stop = mBounds[2*w+1];

        if (mCT_Bounds_Left != 0 && mCT_Bounds_Right != 0) {
          bool outside = true;
          for (int d = cur_rbin_start; d <= cur_rbin_stop; d++) {
            if (h >= mCT_Bounds_Left[w*mNt + d] && h <= mCT_Bounds_Right[w*mNt + d]) {
              outside = false;
              break;
            }
          }
          if (outside) {
            continue;
          }
        }
        // Message to node on the left of current
        //   Sum all input messages and create the message for the node on the right
        //   Messages the current node sends that node is called "mMessage_Right" for that node
        //   Messages from the node to the right are stored in this current node's mMessage_Left
        // ----------------------------------------------------------------
        for (size_t d = cur_rbin_start, message_idx = cur_message_idx+cur_rbin_start; d <= cur_rbin_stop; d++, message_idx++) {
          message_sum[d] = mMessage_Up[message_idx] + mMessage_Right[message_idx] + mMessage_Down[message_idx] - mImage[message_idx];
          // message_in for node on the right (w-1) excludes mMessage_Left which came from the node on the right
        }
        if (w > 0 && (odd_iteration || pass_all)) {
          // Message destination index
          size_t msg_dest_idx = (h + (w-1)*mNsv)*mNt;
          int dest_rbin_start = mBounds[2*w-2];
          int dest_rbin_stop = mBounds[2*w-1];
          // Add binary cost to message being sent to node on the right
          dt(message_sum, &(mMessage_Right[msg_dest_idx]), cur_rbin_start, cur_rbin_stop, dest_rbin_start, dest_rbin_stop, *mAT_Weight, -mAT_Slope[w]);
          // Normalize message so smallest message has a cost of zero
          float min_val = INFINITY;
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            if (mMessage_Right[message_idx] < min_val) {
              min_val = mMessage_Right[message_idx];
            }
          }
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            mMessage_Right[message_idx] = mMessage_Right[message_idx]-min_val;
          }
        }

        // Message to node above the current
        // ----------------------------------------------------------------
        // Input message
        for (size_t d = cur_rbin_start, message_idx = cur_message_idx+cur_rbin_start; d <= cur_rbin_stop; d++, message_idx++) {
          // Add in the missing left message
          message_sum[d] = message_sum[d] + mMessage_Left[message_idx];
          // message_in for node above (h-1) the current excludes mMessage_Up
          message_in[d] = message_sum[d] - mMessage_Up[message_idx];
        }
        if (h > 0 && (odd_iteration || pass_all)) {
          size_t msg_dest_idx = (h-1 + w*mNsv)*mNt;
          int dest_rbin_start = mBounds[2*w];
          int dest_rbin_stop = mBounds[2*w+1];
          // Binary cost
          dt(message_in, &(mMessage_Down[msg_dest_idx]), cur_rbin_start, cur_rbin_stop, dest_rbin_start, dest_rbin_stop, mCT_Weight[h], mCT_Slope[h+w*mNsv]);
          // Normalize message so smallest message has a cost of zero
          float min_val = INFINITY;
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            if (mMessage_Down[message_idx] < min_val) {
              min_val = mMessage_Down[message_idx];
            }
          }
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            mMessage_Down[message_idx] = mMessage_Down[message_idx]-min_val;
          }
        }
        
        // Message to node on the right of current
        // ----------------------------------------------------------------
        for (size_t d = cur_rbin_start, message_idx = cur_message_idx+cur_rbin_start; d <= cur_rbin_stop; d++, message_idx++) {
          message_in[d] = message_sum[d] - mMessage_Right[message_idx];
        }
        if (w < mNx-1 && (!odd_iteration || pass_all)) {
          size_t msg_dest_idx = (h + (w+1)*mNsv)*mNt;
          int dest_rbin_start = mBounds[2*w+2];
          int dest_rbin_stop = mBounds[2*w+3];
          dt(message_in, &(mMessage_Left[msg_dest_idx]), cur_rbin_start, cur_rbin_stop, dest_rbin_start, dest_rbin_stop, *mAT_Weight, mAT_Slope[w]);
          // Normalize message so smallest message has a cost of zero
          float min_val = INFINITY;
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            if (mMessage_Left[message_idx] < min_val) {
              min_val = mMessage_Left[message_idx];
            }
          }
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            mMessage_Left[message_idx] = mMessage_Left[message_idx]-min_val;
          }
        }
        
        // Message to node below the current
        // ----------------------------------------------------------------
        for (size_t d = cur_rbin_start, message_idx = cur_message_idx+cur_rbin_start; d <= cur_rbin_stop; d++, message_idx++) {
          message_in[d] = message_sum[d] - mMessage_Down[message_idx];
        }
        if (h < mNsv-1 && (!odd_iteration || pass_all)) {
          size_t msg_dest_idx = (h+1 + w*mNsv)*mNt;
          int dest_rbin_start = mBounds[2*w];
          int dest_rbin_stop = mBounds[2*w+1];
          dt(message_in, &(mMessage_Up[msg_dest_idx]), cur_rbin_start, cur_rbin_stop, dest_rbin_start, dest_rbin_stop, mCT_Weight[h], -mCT_Slope[h+w*mNsv]);
          // Normalize message so smallest message has a cost of zero
          float min_val = INFINITY;
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            if (mMessage_Up[message_idx] < min_val) {
              min_val = mMessage_Up[message_idx];
            }
          }
          for (size_t d = dest_rbin_start, message_idx = msg_dest_idx+dest_rbin_start; d <= dest_rbin_stop; d++, message_idx++) {
            mMessage_Up[message_idx] = mMessage_Up[message_idx]-min_val;
          }
        }
        
      }
    }
  }
  set_result();
}

// MATLAB FUNCTION START
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
  if (nrhs < 7 || nrhs > 10 || nlhs < 1 || nlhs > 2) {
    mexErrMsgTxt("Usage: [float surface, [debug_output]] = trws(single image, single at_slope, single at_weight, single ct_slope, single ct_weight, uint32 max_loops, uint32 bounds, [unint32 traversal_method, uint32 ct_bounds_left, uint32 ct_bounds_right])\n\n  size(image) is [Nt,Nsv,Nx]\n  mean along-track slope numel(at_slope) is Nx (last element not used)\n  along-track slope weight numel(at_weight) is 1\n  cross-track slope coefficients numel(ct_slope) is Nsv  (last element not used)\n  cross-track slope weight numel(ct_weight) is Nsv  (last element not used)\n  numel(max_loops) is 1\n  numel(bounds) is 2*size(image,3)\n  numel(traversal_method) is 1\n  numel(ct_bounds_left/right) is size(image, 1)*size(image, 3)");
  }

  int arg = -1;
  
  arg++;
  // image ================================================================
  if (!mxIsSingle(prhs[arg])) {
    mexErrMsgTxt("usage: image must be type single");
  }
  if (mxGetNumberOfDimensions(prhs[arg]) != 3) {
    mexErrMsgTxt("usage: image must be a 3D matrix [rows=Nt, columns=Ndoa, slices=Nx]");
  }
  const size_t *dim_image = mxGetDimensions(prhs[arg]);
  float *image = reinterpret_cast<float *>(mxGetData(prhs[arg]));
  // dim_image[0]: Nt rows of one slice (fast-time: the hidden state we are trying to estimate)
  // dim_image[1]: Nsv cols of one slice (cross-track dimension)
  // dim_image[2]: Nx number of slices (along-track dimension)
  
  arg++;
  // at_slope =============================================================
  if (!mxIsSingle(prhs[arg])) {
    mexErrMsgTxt("usage: at_slope must be type single (float32)");
  }
  if (mxGetNumberOfElements(prhs[arg]) != dim_image[2]) {
    mexErrMsgTxt("usage: at_slope must have numel equal to size(image,3)");
  }
  float *at_slope = reinterpret_cast<float *>(mxGetData(prhs[arg]));
  
  arg++;
  // at_weight ============================================================
  if (!mxIsSingle(prhs[arg])) {
    mexErrMsgTxt("usage: at_weight must be type single (float32)");
  }
  if (mxGetNumberOfElements(prhs[arg]) != 1) {
    mexErrMsgTxt("usage: at_weight must have numel equal to 1");
  }
  float *at_weight = reinterpret_cast<float *>(mxGetData(prhs[arg]));
  
  arg++;
  // ct_slope =============================================================
  if (!mxIsSingle(prhs[arg])) {
    mexErrMsgTxt("usage: ct_slope must be type single (float32)");
  }
  const size_t *dim_ct_slope = mxGetDimensions(prhs[arg]);
  if (dim_ct_slope[0] != dim_image[1] || dim_ct_slope[1] != dim_image[2]) {
    mexErrMsgTxt("usage: ct_slope must have size(ct_slope,1)=size(image,2) and size(ct_slope,2)=size(image,3)");
  }
  float *ct_slope = reinterpret_cast<float *>(mxGetData(prhs[arg]));
  
  arg++;
  // ct_weight ============================================================
  if (!mxIsSingle(prhs[arg])) {
    mexErrMsgTxt("usage: ct_weight must be type single (float32)");
  }
  if (mxGetNumberOfElements(prhs[arg]) != dim_image[1]) {
    mexErrMsgTxt("usage: ct_weight must have numel equal to size(image,2)");
  }
  float *ct_weight = reinterpret_cast<float *>(mxGetData(prhs[arg]));
  
  arg++;
  // max_loops ===========================================================
  if (!mxIsClass(prhs[arg],"uint32")) {
    mexErrMsgTxt("usage: max_loops must be type unsigned int32");
  }
  if (mxGetNumberOfElements(prhs[arg]) != 1) {
    mexErrMsgTxt("usage: max_loops must have numel equal to 1");
  }
  unsigned int max_loops = *reinterpret_cast<unsigned int *>(mxGetData(prhs[arg]));
  
  arg++;
  // bounds ===============================================================
  if (!mxIsClass(prhs[arg],"uint32")) {
    mexErrMsgTxt("usage: bounds must be type unsigned int32");
  }
  if (mxGetNumberOfElements(prhs[arg]) != dim_image[2]*2) {
    mexErrMsgTxt("usage: bounds must have numel equal to 2*size(image,3)");
  }
  unsigned int *bounds = reinterpret_cast<unsigned int *>(mxGetData(prhs[arg]));
  
  // traversal_method ===============================================================
  unsigned int traversal_method = 0;
  arg++;
  if (nrhs > arg) {
    if (!mxIsClass(prhs[arg],"uint32")) {
      mexErrMsgTxt("usage: traversal_method must be type unsigned int32");
    }
    if (mxGetNumberOfElements(prhs[arg]) != 1) {
      mexErrMsgTxt("usage: traversal_method must have numel equal to 1");
    }
    traversal_method = *reinterpret_cast<unsigned int *>(mxGetData(prhs[arg]));
  }

  unsigned int *ct_bounds_left = 0;
  unsigned int *ct_bounds_right = 0;
  arg++;
  if (nrhs > arg) {
    if (nrhs <= arg + 1) {
      mexErrMsgTxt("usage: ct_bounds_right must be present as well when given ct_bounds_left.");
    }
    // ct_bounds_left ===============================================================
    if (!mxIsClass(prhs[arg],"uint32")) {
      mexErrMsgTxt("usage: ct_bounds_left must be type unsigned int32");
    }
    if (mxGetNumberOfElements(prhs[arg]) != dim_image[0]*dim_image[2]) {
      mexErrMsgTxt("usage: ct_bounds_left must have numel equal to size(image,1)*size(image,3)");
    }
    ct_bounds_left = reinterpret_cast<unsigned int *>(mxGetData(prhs[arg]));
    arg++;
    // ct_bounds_right ===============================================================
    if (!mxIsClass(prhs[arg],"uint32")) {
      mexErrMsgTxt("usage: ct_bounds_right must be type unsigned int32");
    }
    if (mxGetNumberOfElements(prhs[arg]) != dim_image[0]*dim_image[2]) {
      mexErrMsgTxt("usage: ct_bounds_right must have numel equal to size(image,1)*size(image,3)");
    }
    ct_bounds_right = reinterpret_cast<unsigned int *>(mxGetData(prhs[arg]));
  }

  
  // Allocate output
  plhs[0] = mxCreateNumericMatrix(dim_image[1], dim_image[2], mxSINGLE_CLASS, mxREAL);
  float *result = reinterpret_cast<float *>(mxGetData(plhs[0]));

  float *debug = 0;
  if (nlhs == 2) {
    // Debug mode
    plhs[1] = mxCreateNumericArray(3, dim_image, mxSINGLE_CLASS, mxREAL);
    debug = reinterpret_cast<float *>(mxGetData(plhs[1]));
  }
  
  // RUN TRWS2
  TRWS obj(image, dim_image, at_slope, at_weight, ct_slope, ct_weight, max_loops, bounds, traversal_method, ct_bounds_left, ct_bounds_right, result, debug);

  obj.solve();
}
