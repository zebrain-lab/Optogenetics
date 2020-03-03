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
    int index;
    AT_BOOL boolean;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=3) {
        mexErrMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:InvalidNumInput","Need 3 input arguments.");    
    }
    if(nlhs!=1) {
        mexErrMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:InvalidNumOutput","Need 1 output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:InvalidInput","First input should be a scalar.");     
    }
    if (!mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:InvalidInput","Second input should be a string.");     
    }
    if (!mxIsScalar(prhs[2])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:InvalidInput","Third input should be a scalar.");     
    }
    
    // get the value of the inputs
    handle = (AT_H) mxGetScalar(prhs[0]);
    strinput = mxArrayToString(prhs[1]);
    mbstowcs(feature, strinput, STRLEN);
    index = (int) mxGetScalar(prhs[2]);
    
    // call the lib function
    ret = AT_IsEnumIndexImplemented(handle, feature, index, &boolean);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_IsEnumIndexImplemented:ReturnFailure","Library returned error %d",ret);
    }
    
    // set the value of the outputs
    plhs[0] = mxCreateDoubleScalar(boolean);
    
    // release memory
    mxFree(strinput);
}