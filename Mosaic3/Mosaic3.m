classdef Mosaic3 < handle
    
    properties
        handle
        buffer
    end
 
    methods
        function obj = Mosaic3(cameraDevice)
            AT_InitialiseLibrary();
            obj.handle = AT_Open(cameraDevice);
        end
        
        function delete(obj)
            AT_Close(obj.handle);
            AT_FinaliseLibrary();
        end
        
        function command(obj,str)
            AT_Command(obj.handle,str);
        end
        
        function ret = getBool(obj,str)
            ret = AT_GetBool(obj.handle,str);
        end
        
        function ret = getEnumCount(obj,str)
            ret = AT_GetEnumCount(obj.handle,str);
        end
        
        function ret = getEnumIndex(obj,str)
            ret = AT_GetEnumIndex(obj.handle,str);
        end
        
        function ret = getEnumStringByIndex(obj,str,ind)
            ret = AT_GetEnumStringByIndex(obj.handle,str,ind);
        end
        
        function ret = getFloat(obj,str)
            ret = AT_GetFloat(obj.handle,str);
        end
        
        function ret = getFloatMax(obj,str)
            ret = AT_GetFloatMax(obj.handle,str);
        end
        
        function ret = getFloatMin(obj,str)
            ret = AT_GetFloatMin(obj.handle,str);
        end
        
        function ret = getInt(obj,str)
            ret = AT_GetInt(obj.handle,str);
        end
        
        function ret = System_getInt(obj,str)
            ret = AT_GetInt(1,str);
        end
        
        function ret = getIntMax(obj,str)
            ret = AT_GetIntMax(obj.handle,str);
        end
        
        function ret = getIntMin(obj,str)
            ret = AT_GetIntMin(obj.handle,str);
        end
        
        function ret = getString(obj,str)
            ret = AT_GetString(obj.handle,str);
        end
        
        function ret = System_getString(obj,str)
            ret = AT_GetString(1,str);
        end
        
        function ret = getStringMaxLength(obj,str)
            ret = AT_GetStringMaxLength(obj.handle,str);
        end
        
        function ret = isEnumIndexAvailable(obj,str,ind)
            ret = AT_IsEnumIndexAvailable(obj.handle,str,ind);
        end
        
        function ret = isEnumIndexImplemented(obj,str,ind)
            ret = AT_IsEnumIndexImplemented(obj.handle,str,ind);
        end
        
        function ret = isImplemented(obj,str)
            ret = AT_IsImplemented(obj.handle,str);
        end
        
        function ret = isReadable(obj,str)
            ret = AT_IsReadable(obj.handle,str);
        end
        
        function ret = isReadOnly(obj,str)
            ret = AT_IsReadOnly(obj.handle,str);
        end
        
        function ret = isWritable(obj,str)
            ret = AT_IsWritable(obj.handle,str);
        end
        
        function queueBuffer(obj,buf)
            obj.buffer = buf;
            AT_QueueBuffer(obj.handle,obj.buffer,length(buf));
        end
        
        function setBool(obj,str,val)
            AT_SetBool(obj.handle,str,val);
        end
        
        function setEnumIndex(obj,str,val)
            AT_SetEnumIndex(obj.handle,str,val);
        end
        
        function setEnumString(obj,str,val)
            AT_SetEnumString(obj.handle,str,val);
        end
        
        function setFloat(obj,str,val)
            AT_SetFloat(obj.handle,str,val);
        end
        
        function setInt(obj,str,val)
            AT_SetInt(obj.handle,str,val);
        end
        
        function setString(obj,str,val)
            AT_SetString(obj.handle,str,val);
        end
    end
end