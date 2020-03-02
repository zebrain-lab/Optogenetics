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
    AT_WC stringbuf[STRLEN];
    char stroutput[STRLEN];
    int index;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=3) {
        mexErrMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:InvalidNumInput","Need 3 input arguments.");    
    }
    if(nlhs!=1) {
        mexErrMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:InvalidNumOutput","Need 1 output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:InvalidInput","First input should be a scalar.");     
    }
    if (!mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:InvalidInput","Second input should be a string.");     
    }
    if (!mxIsScalar(prhs[2])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:InvalidInput","Third input should be a scalar.");     
    }
    
    // get the value of the inputs
    handle = (AT_H) mxGetScalar(prhs[0]);
    strinput = mxArrayToString(prhs[1]);
    mbstowcs(feature, strinput, STRLEN);
    index = (int) mxGetScalar(prhs[2]);
    
    // call the lib function
    ret = AT_GetEnumStringByIndex(handle, feature, index, stringbuf, STRLEN); 
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_GetEnumStringByIndex:ReturnFailure","Library returned error %d",ret);
    }
    
    // set the value of the outputs
    wcstombs(stroutput, stringbuf, STRLEN);
    plhs[0] = mxCreateString(stroutput);
    
    // release memory
    mxFree(strinput);
}
