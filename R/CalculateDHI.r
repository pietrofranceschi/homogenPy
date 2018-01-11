#' Calculate DHI value for drug MSI data
#'
#' @name CalculateDHI
#' @description This function calculates the DHI value for the drug image derived from MSI data.
#' @usage CalculateDHI(drugImg,maskImg,QuantLevel=0,Nu=1)
#' @param
#' @param  drugImg  Input data matrix of drug ion image
#' @param  maskImg Input data matrix of tissue masked image
#' @param  QuantLevel  Maximum possible gray-levels in drug ion image. default =0, i.e., original image
#' @param Nu  Lowest size-zone value used for DHI calculation. default = 1
#'
#' @details
#' The algorithm is based on the following workflow:
#' \enumerate{
#' \item Derive new quantized drug image at user-defined qunatization value.
#' \item Derive gray-level size-zone matrix (GLSZM) for new drug quantized image (default value =0).
#' \item Derive homogeneous size-zone value from GLSZM at user-defined Nu value (default value =1).
#' \item Normalized overall value with complete tumor area which is obtained from tumor mask file.
#' }
#' @return DHI value for given drug ms file
#' @author Mridula Prasad \email{mridula.prasad@fmach.it}
#' @references \url{https://github.com/pietrofranceschi/HomogenMSI}
#' @examples
#' ## load package
#' library(HomogenMSI)
#' data("DHIimages")
#'
#' ## Input drug and mask images
#'
#' drugImg = DHIimages[[2]]
#' maskImg = DHIimages[[1]]
#' maskImg[maskImg !=0] =1
#'
#' #Calculate DHI with default input parameters
#' print(CalculateDHI(drugImg,maskImg))
#'
#' # calculate DHI with user-defined Nu value
#' print(CalculateDHI(drugImg,maskImg,QuantLevel=0,Nu=5))
#'
#' @export
#'

suppressMessages(library("spatstat"))
suppressMessages(library("reshape2"))

##### calculate DHI value from given MSI data


CalculateDHI <- function(drugImg,maskImg,QuantLevel=0,Nu=1)
{
 if((dim(drugImg)[1] != dim(maskImg)[1]) | (dim(drugImg)[2] != dim(maskImg)[2]))
   {stop("dimensions of drug and mask image matrices are different")}
  if(QuantLevel !=0)
  {
  m = QuantLevel/max(drugImg)
  drugImg = drugImg*m
  }
  drugImg= maskImg * drugImg
  
  # unique number of gray levels in image
  grey_lvls <- unique(c(drugImg))
  grey_lvls <- grey_lvls[!is.na(grey_lvls)]
   
   #convert to data for use with spatstats functions
  ImgMat = spatstat::as.im(drugImg)
  #Initialize dataframe to hold count data
  szm <- data.frame()
  
   for(i in grey_lvls)
	 {
              # Threshold the data
              imBinary <- spatstat::levelset(ImgMat, i, compare="==")
              connections <- spatstat::connected(imBinary)
              
              # Extract counts of each uniqe value 
              counts <- table(table(as.matrix(connections)))
              szm <- rbind(szm, data.frame(i, counts))
            }
			
	#Clean up names 
    colnames(szm) <- c("greylvl", "size", "counts")
    #cast to matrix
    szm <- reshape2::acast(szm, greylvl~size, value.var="counts")
    #sort columns, if there is only a single size a vector is returned, hence the if
    if(length(colnames(szm)) > 1 && nrow(szm) > 1){
         szm <- szm[,order(as.numeric(as.character(colnames(szm))))]
        }
  szm[is.na(szm)] <- 0		
  szm <- szm[,which(colSums(szm)>0)]
  szm = szm[-1,]   ### Removing sz values for the background of image
  szm = szm[,-as.numeric(which(colSums(szm) ==0 ))]
  szv = as.numeric(colnames(szm))
  id = which(szv >= Nu)
  DrugHomo = 0
  for(j in 1:length(id))
  {
    DrugHomo = DrugHomo + (szv[id[j]]) * sum(szm[,id[j]])
  }
  DrugHomo = DrugHomo/sum(szm[,id])
  TumorArea = table(maskImg)[[2]]
  DrugHomo = DrugHomo/TumorArea

  return(DrugHomo)
}