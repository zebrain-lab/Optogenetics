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
    char *strinput1;
    AT_WC feature[STRLEN];
    char *strinput2;
    AT_WC strvalue[STRLEN];
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=3) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetString:InvalidNumInput","Need 3 input arguments.");
    }
    if(nlhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetString:InvalidNumOutput","Need no output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetString:InvalidInput","First input should be a scalar.");     
    }
    if (!mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetString:InvalidInput","Second input should be a string.");     
    }
    if (!mxIsChar(prhs[2])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_SetString:InvalidInput","Third input should be a string.");     
    }
    
    // get the value of the inputs
    handle = (AT_H) mxGetScalar(prhs[0]);
    strinput1 = mxArrayToString(prhs[1]);
    mbstowcs(feature, strinput1, STRLEN);
    strinput2 = mxArrayToString(prhs[2]);
    mbstowcs(strvalue, strinput2, STRLEN);
    
    // call the lib function
    ret = AT_SetString(handle, feature, strvalue);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_SetString:ReturnFailure","Library returned error %d",ret);
    }
    
    // release memory
    mxFree(strinput1);
    mxFree(strinput2);
}
