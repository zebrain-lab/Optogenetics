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
#include "stdlib.h"
#define STRLEN 512

/* The gateway function */
void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[])
{

    // define arguments to the C function with the right type
    AT_H handle;
    char *strinput;
    AT_WC feature[STRLEN];
    double value;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=3) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetFloat:InvalidNumInput","Need 3 input arguments.");
    }
    if(nlhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetFloat:InvalidNumOutput","Need no output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetFloat:InvalidInput","First input should be a scalar.");     
    }
    if (!mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetFloat:InvalidInput","Second input should be a string.");     
    }
    if (!mxIsDouble(prhs[2])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetFloat:InvalidInput","Third input should be a double.");     
    }
    
    // get the value of the inputs
    handle = (AT_H) mxGetScalar(prhs[0]);
    strinput = mxArrayToString(prhs[1]);
    mbstowcs(feature, strinput, STRLEN);
    value = (double) mxGetScalar(prhs[2]);
    
    // call the lib function
    ret = AT_SetFloat(handle, feature, value);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_SetFloat:ReturnFailure","Library returned error %d",ret);
    }
    
    // release memory
    mxFree(strinput);
}

