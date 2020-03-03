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
    AT_H handle;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=1) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Close:InvalidNumInput","Need 1 input arguments.");
    }
    if(nlhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Close:InvalidNumOutput","No output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_Close:InvalidInput","First input should be a scalar.");     
    }
    
    // get the value of the inputs
    handle = mxGetScalar(prhs[0]);
    
    // create the output

    // call the lib function
    ret = AT_Close(handle);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_Close:ReturnFailure","Library returned error %d",ret);
    }
}
