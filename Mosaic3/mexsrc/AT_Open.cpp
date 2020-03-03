/*==========================================================
 * MATLAB wrapper to the ANDOR Mosaic SDK 3 
 *
 * What the function does
 *
 * The calling syntax is:
 *
 *		lhs = name_function(rhs1, rhs2)
 *
 * This is a MEX-file for MATLAB.
 * Martin Privat
 * Dec 2019
 *
 *========================================================*/

#include "mex.h"
#include "atcore.h"

/* The gateway function */
void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[])
{
    // define arguments to the C function with the right type
    int cameraIndex;
    AT_H handle;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=1) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Open:InvalidNumInput","Need 1 input argument.");
    }
    if(nlhs!=1) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Open:InvalidNumOutput","Need 1 output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Open:InvalidInput","First input should be a scalar.");     
    }
    
    // get the value of the inputs
    cameraIndex = (int) mxGetScalar(prhs[0]);
    
    // call the lib function
    ret = AT_Open(cameraIndex, &handle);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_Open:ReturnFailure","Library returned error %d",ret);
    }
    
    // set the value of the outputs
    plhs[0] = mxCreateDoubleScalar(handle);
}
