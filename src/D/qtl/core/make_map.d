/**
 * Module for making a new map with inserted inter-marker locations
 */

module qtl.core.make_map;

import std.container;
import std.stdio;
import std.conv;
import std.string;
import std.path;

import qtl.core.primitives;
import qtl.core.genotype;

/**
 * The make_fixed_map function creates a new map for a chromosome, and 
 * inserts Pseudo markers at fixed positions.
 *
 * In R/qtl one function existed for fixed_distance_map, 
 * fixed_distance_map_sex and add_marker_if_single.
 *
 * markers:        List of markers (one chromosome)
 * step:           Step size (in cM)
 * off_end:        Max distance (in cM) past the terminal marker
 */

Markers!T make_fixed_map(T)(in Markers!T markers, Position step, Position off_end)
  in {
    assert(step>0);
    assert(off_end>=0);
  }
  body {
  // if step is zero, the purpose was to add a marker if there is only one.
  // This is no longer the case, use add_marker_if_single instead.

/*
 Non sex specific map:
  if(!is.matrix(map)) { # sex-ave map
    if(length(map) == 1) { # just one marker!
      if(off.end==0) {
        if(step == 0) step <- 1
        nam <- names(map)
        map <- c(map,map+step)
        names(map) <- c(nam,paste("loc",step,sep=""))
      }
      else {
        if(step==0) m <- c(-off.end,off.end)
        else m <- seq(-off.end,off.end,by=step)
        m <- m[m!=0]
        names(m) <- paste("loc",m,sep="")
        map <- sort(c(m+map,map))
      }
      return(map)
    }

    minloc <- min(map)
    map <- map-minloc

    if(step==0 && off.end==0) return(map+minloc)
    else if(step==0 && off.end > 0) {
      a <- c(floor(min(map)-off.end),ceiling(max(map)+off.end))
      names(a) <- paste("loc", a, sep="")
      return(sort(c(a,map))+minloc)
    }
    else if(step>0 && off.end == 0) {
      a <- seq(floor(min(map)),max(map),
               by = step)
      if(any(is.na(match(a, map)))) {
        a <- a[is.na(match(a,map))]
        names(a) <- paste("loc",a,sep="")
        return(sort(c(a,map))+minloc)
      }
      else return(map+minloc)
    }
    else {
      a <- seq(floor(min(map)-off.end),ceiling(max(map)+off.end+step),
               by = step)
      a <- a[is.na(match(a,map))]

      # no more than one point above max(map)+off.end
      z <- (seq(along=a))[a >= max(map)+off.end]
      if(length(z) > 1) a <- a[-z[-1]]

      names(a) <- paste("loc",a,sep="")
      return(sort(c(a,map))+minloc)
    }
  } # end sex-ave map
 */
  return null;
}

Markers!T make_fixed_map_sex(T)(in Markers!T markers, Position step, Position off_end)
{
  /*
  else { # sex-specific map
    if(stepwidth == "variable") {
      if(off.end > 0) {
        tmp <- colnames(map)
        map <- cbind(map[, 1] - off.end, map, map[, ncol(map)] + off.end)
        dimnames(map) <- list(NULL, c("loc000", tmp, "loc999"))
      }
      if(step == 0)
        return(unclass(map))

      ## Determine differences and expansion vector.
      dif <- diff(map[1, ])
      expand <- pmax(1, floor(dif / step))

      ## Create pseudomarker map.
      a <- min(map[1, ]) + cumsum(c(0, rep(dif / expand, expand)))
      b <- min(map[2, ]) + cumsum(c(0, rep(diff(map[2, ]) / expand, expand)))

      namesa <- paste("loc", seq(length(a)), sep = "")
      namesa[cumsum(c(1, expand))] <- dimnames(map)[[2]]
      map <- rbind(a,b)
      dimnames(map) <- list(NULL, namesa)

      return(unclass(map))
    }
    if(stepwidth == "max") {
      if(step==0 && off.end==0) return(unclass(map))
      if(step==0 && off.end>0) {
        if(ncol(map)==1) { # only one marker; assume equal recomb in sexes
          L1 <- L2 <- 1
        }
        else {
          L1 <- diff(range(map[1,]))
          L2 <- diff(range(map[2,]))
        }

        nam <- colnames(map)
        nmap1 <- c(map[1,1]-off.end, map[1,], map[1,ncol(map)]+off.end)
        nmap2 <- c(map[2,1]-off.end*L2/L1, map[2,], map[2,ncol(map)]+off.end*L2/L1)
        map <- rbind(nmap1, nmap2)
        colnames(map) <- c("loc1", nam, "loc2")
        return(unclass(map))
      }

      if(ncol(map)==1) L1 <- L2 <- 1
      else {
        L1 <- diff(range(map[1,]))
        L2 <- diff(range(map[2,]))
      }

      nam <- colnames(map)

      if(off.end > 0) {
        toadd1 <- c(map[1,1] - off.end, map[1,ncol(map)]+off.end)
        toadd2 <- c(map[2,1] + off.end*L2/L1, map[2,ncol(map)]+off.end*L2/L1)

        neword <- order(c(map[1,], toadd1))
        nmap1 <- c(map[1,], toadd1)[neword]
        nmap2 <- c(map[2,], toadd2)[neword]
      }
      else {
        nmap1 <- map[1,]
        nmap2 <- map[2,]
        toadd1 <- toadd2 <- NULL
      }

      d <- diff(nmap1)
      nadd <- ceiling(d/step)-1
      if(sum(nadd) > 0) {
        for(j in 1:(length(nmap1)-1)) {
          if(nadd[j]>0) {
            toadd1 <- c(toadd1, seq(nmap1[j], nmap1[j+1], len=nadd[j]+2)[-c(1,nadd[j]+2)])
            toadd2 <- c(toadd2, seq(nmap2[j], nmap2[j+1], len=nadd[j]+2)[-c(1,nadd[j]+2)])
          }
        }
      }
      newnam <- paste("loc", 1:length(toadd1), sep="")
      
      toadd1 <- sort(toadd1)
      toadd2 <- sort(toadd2)
      neword <- order(c(map[1,], toadd1))
      nmap1 <- c(map[1,], toadd1)[neword]
      nmap2 <- c(map[2,], toadd2)[neword]
      map <- rbind(nmap1, nmap2)
      colnames(map) <- c(nam, newnam)[neword]

      return(unclass(map))
    }

    minloc <- c(min(map[1,]),min(map[2,]))
    map <- unclass(map-minloc)
    markernames <- colnames(map)

    if(step==0 && off.end==0) return(map+minloc)
    else if(step==0 && off.end > 0) {
      map <- map+minloc
      if(ncol(map)==1) { # only one marker; assume equal recomb in sexes
        L1 <- L2 <- 1
      }
      else {
        L1 <- diff(range(map[1,]))
        L2 <- diff(range(map[2,]))
      }

      nam <- colnames(map)
      nmap1 <- c(map[1,1]-off.end, map[1,], map[1,ncol(map)]+off.end)
      nmap2 <- c(map[2,1]-off.end*L2/L1, map[2,], map[2,ncol(map)]+off.end*L2/L1)
      map <- rbind(nmap1, nmap2)
      colnames(map) <- c("loc1", nam, "loc2")
      return(map)
    }
    else if(step>0 && off.end == 0) {

      if(ncol(map)==1) return(map+minloc)

      a <- seq(floor(min(map[1,])),max(map[1,]),
               by = step)
      a <- a[is.na(match(a,map[1,]))]

      if(length(a)==0) return(map+minloc)

      b <- sapply(a,function(x,y,z) {
          ZZ <- min((seq(along=y))[y > x])
          (x-y[ZZ-1])/(y[ZZ]-y[ZZ-1])*(z[ZZ]-z[ZZ-1])+z[ZZ-1] }, map[1,],map[2,])

      m1 <- c(a,map[1,])
      m2 <- c(b,map[2,])

      names(m1) <- names(m2) <- c(paste("loc",a,sep=""),markernames)
      return(rbind(sort(m1),sort(m2))+minloc)
    }
    else {
      a <- seq(floor(min(map[1,])-off.end),ceiling(max(map[1,])+off.end+step),
               by = step)
      a <- a[is.na(match(a,map[1,]))]
      # no more than one point above max(map)+off.end
      z <- (seq(along=a))[a >= max(map[1,])+off.end]
      if(length(z) > 1) a <- a[-z[-1]]

      b <- sapply(a,function(x,y,z,ml) {
        if(x < min(y)) {
          return(min(z) - (min(y)-x)/diff(range(y))*diff(range(z)) - ml)
        }
        else if(x > max(y)) {
          return(max(z) + (x - max(y))/diff(range(y))*diff(range(z)) - ml)
        }
        else {
          ZZ <- min((seq(along=y))[y > x])
          (x-y[ZZ-1])/(y[ZZ]-y[ZZ-1])*(z[ZZ]-z[ZZ-1])+z[ZZ-1]
        }
        }, map[1,],map[2,], minloc[2])
      m1 <- c(a,map[1,])
      m2 <- c(b,map[2,])
      names(m1) <- names(m2) <- c(paste("loc",a,sep=""),markernames)
      return(rbind(sort(m1),sort(m2))+minloc)
    }
  }
}
*/
  return null;
}

/**
 * Add a marker if there is only one
 */

Markers!T add_if_single_marker(T)(Markers!T markers, Position step)
in {
    assert(step>0);
  }
body {
  if (markers.list.length == 1) {
    auto marker = markers.list[0].marker;
    auto position = marker.position + step;
    auto pm = new Marker(position,ID_UNKNOWN,"loc" ~ to!string(position));
    markers.list ~= new MarkerRef!T(pm);
    return markers;
  }
  return markers;
}

unittest {
  writeln("Unit test " ~ __FILE__);
  auto markers = new Markers!F2();
  markers.list ~= new MarkerRef!F2(10.0);
  assert(markers.list.length == 1);
  auto new_markers = add_if_single_marker!F2(markers,100.0);
  assert(new_markers.list.length == 2, "Length is " ~ to!string(new_markers.list.length));
  assert(new_markers.list[1].marker.position == 110.0);
  assert(new_markers.list[1].marker.name == "loc110", new_markers.list[1].marker.name);
}

