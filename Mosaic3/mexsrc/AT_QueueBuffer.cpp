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
    AT_U8* data;
    int datalen;
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=3) {
        mexErrMsgIdAndTxt("Optogenetics:AT_QueueBuffer:InvalidNumInput","Need 3 input arguments.");
    }
    if(nlhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_QueueBuffer:InvalidNumOutput","Need no output argument.");
    }
    
    // make sure that input argument have the right type
    if (!mxIsScalar(prhs[0])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_QueueBuffer:InvalidInput","First input should be a scalar.");     
    }
    if (!mxIsUint8(prhs[1])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_QueueBuffer:InvalidInput","Second input should be an uint8 array.");     
    }
    if (!mxIsScalar(prhs[2])) {
        mexErrMsgIdAndTxt("Optogenetics:AT_QueueBuffer:InvalidInput","Third input should be a scalar.");     
    }
    
    // get the value of the inputs
    handle = mxGetScalar(prhs[0]);
    data = (AT_U8*) mxGetPr(prhs[1]);
    datalen = mxGetScalar(prhs[2]);

    // call the lib function
    ret = AT_QueueBuffer(handle, data, datalen);
    if (ret != 0) {
        mexWarnMsgIdAndTxt("Optogenetics:AT_QueueBuffer:ReturnFailure","Library returned error %d",ret);
    }
}
