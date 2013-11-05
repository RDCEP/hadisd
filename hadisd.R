#!/software/R-2.15-el6-x86_64/bin/Rscript

library( raster)
library( ncdf4)
library( stringr)

# setwd( "hadisd2012/hadisd.1.0.0.2011f.501360-99999")

nc <- nc_open( "merge.nc4")

lonLat <- matrix(
  c( x= ncatt_get( nc, 0, "longitude")$value,
    y= ncatt_get( nc, 0, "latitude")$value),
  nrow= 1)


world <- raster()
res( world) <- 30 / 60 / 60

rowCol <- rowColFromCell(world, cellFromXY( world, lonLat))

dailyPath <- with(
  as.list( rowCol[ 1,]),
  sprintf(
    "../../daily/%1$d/%2$d/%1$d_%2$d.psims.nc",
    row, col))

dir.create(
  dirname( dailyPath),
  recursive= TRUE)

station <- str_match(
  basename( getwd()),
  "\\.([0-9]{6})-[0-9]+$")[,2]

if( station %in% c( "766340", "971800")) {
  dailyPath <- str_c( dailyPath, ".1")
}

if( station %in% c( "766342", "971820")) {
  dailyPath <- str_c( dailyPath, ".2")
}

ncdump <- pipe(
  str_c(
    "ncdump -fC -n ",
    str_replace( basename(dailyPath), "\\.nc$", ""),
    " merge.nc4"),
  open= "r")
ncgen <- pipe( str_c( "ncgen -b -k1 -o ", dailyPath), open= "w")
## ncgen <- ""
inTimeStanza <- FALSE
inHeader <- TRUE
cat(
  readLines( ncdump, n= 2),
  "\tlongitude = 1 ;",
  "\tlatitude = 1 ;",
  readLines( ncdump, n= 1),
  sep= "\n",
  file= ncgen)
## soFar <- 5

## options( warn= 2, error= recover)
## options( warn= 0, error= NULL)  # the defaults

repeat {
  cdl <- readLines( ncdump, n= 1)
  if( length( cdl) == 0) {
    close( ncdump)
    close( ncgen)
    break
  }
  ## soFar <- soFar + 1
  if( inHeader) {
    if( str_detect( cdl, "^data:$")) {
      inHeader <- FALSE
      xy <- xyFromCell(
        world,
        cellFromRowCol( world, rowCol[1,1], rowCol[1,2]))
      cdl <- c(
        cdl,
        "",
        str_c(
          " longitude = ",
          as.character( xy[1,1]), " ;"),
        "",
        str_c(
          " latitude = ",
          as.character( xy[1,2]), " ;"))
    } else {
      if( str_detect( cdl, "^variables:$")) {
        cdl <- c(
          cdl,
          "\tdouble longitude(longitude) ;",
          "\t\tlongitude:units = \"degrees_east\" ;",
          "\t\tlongitude:long_name = \"longitude\" ;",
          "\tdouble latitude(latitude) ;",
          "\tlatitude:units = \"degrees_north\" ;",
          "\tlatitude:long_name = \"latitude\" ;")
      }
      if( ## suppressWarnings(
        str_detect( cdl[1], "^\\tdouble time\\(time\\) ;")) {
        cdl <- "\tinteger time(time) ;"
      } else {
        nonDimVar <- str_match(
          cdl, "^(\\t[^(]*\\(time)\\) ;")[ 1, 2]
        if( !is.na( nonDimVar)) {
          cdl <- str_c( nonDimVar, ", latitude, longitude) ;")
        }
      }
    }
  }
  if( !inTimeStanza) {
    ## inTimeStanza <- str_detect( cdl, perl( "^\\s*time ="))
    inTimeStanza <- str_detect( cdl[1], "^ *time =")
  }
  if( inTimeStanza) {
    if( str_detect( cdl[1], "^ *$")) {
      inTimeStanza <- FALSE
      ## break
    } else {
      cdlFields <- str_match(
        cdl,
        ## perl( "^(\\s*(time = )?)([.0-9]+)(.*)"))
        "^( *(time = )?)([.0-9]+)(.*)")
      cdl <- str_c(
        cdlFields[ 2],
        ceiling( as.numeric( cdlFields[ 4])),
        cdlFields[ 5])
    }
  }
  cat( cdl, sep= "\n", file= ncgen)
  ## if( soFar >= 200) break
}

## closeAllConnections()
