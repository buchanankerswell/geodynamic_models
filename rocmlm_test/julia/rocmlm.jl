#######################################################
## .0.              Load Libraries               !!! ##
#######################################################
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# utilities !!
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
using PyCall

#######################################################
## .1.             Helper Functions              !!! ##
#######################################################

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# load pkl !!
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function load_pkl(file_path::String) :: PyObject
    """
    """
    if !isfile(file_path)
        error("Invalid file path: $file_path")
    end
    
    try
        @eval using PyCall
    catch
        error("PyCall could not be loaded. Make sure it is installed ...")
    end
    
    joblib = pyimport("joblib")
    
    return joblib.load(file_path)
end

#######################################################
## .2.             RocMLM Functions              !!! ##
#######################################################

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rocmlm predict !!
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function rocmlm_predict(input_ft::Matrix{Float64}, rocmlm_path::String) :: Matrix{Float64}
    """
    """
    if !isfile(rocmlm_path)
        throw(ArgumentError("Did not find RocMLM at: $rocmlm_path"))
    end

    scaler_X_path = replace(rocmlm_path, "model-only" => "scaler_X")
    scaler_y_path = replace(rocmlm_path, "model-only" => "scaler_y")

    rocmlm, scaler_X, scaler_y = nothing, nothing, nothing

    try
        rocmlm = load_pkl(rocmlm_path)
        scaler_X = load_pkl(scaler_X_path)
        scaler_y = load_pkl(scaler_y_path)
    catch e
        throw(ArgumentError("Error loading file: $e"))
    end

    input_ft_scaled = scaler_X.transform(input_ft)
    pred = rocmlm.predict(input_ft_scaled)
    pred_original = scaler_y.inverse_transform(pred)

    return pred_original
end

#######################################################
## .3.           Plotting Functions              !!! ##
#######################################################

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rectangle from coords !!
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function rectangle_from_coords(xb, yb, xt, yt) :: Matrix{Float64}
    return [xb yb; xt yb; xt yt; xb yt; xb yb; NaN NaN]
end
