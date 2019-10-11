---
title: "Using TargetScore Shiny App"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteIndexEntry{Using TargetScore}
  %\VignetteEncoding{UTF-8}
---

```{r setup, echo=FALSE, warning=FALSE, message=FALSE}
require("knitr")
opts_knit$set(root.dir="..")
opts_chunk$set(fig.align="center", fig.width=6, fig.height=6, dpi=300)
```

# Purpose 

This tutorial describes the basic usage of TargetScore. 

# Setup 

## Load Packages 

```{r}
library(pheatmap)
library(glasso)
library(zeptosensPkg)
library(zeptosensUtils)
library(ggplot2)
library(ggrepel)
```

## Load Data 

```{r}
  #file from input
    #Drug File
  DrugDat <- shiny:::reactive({
    DrugFile<-input$DrugData
    if (is.null(DrugFile))
       return(NULL)
    if(input$header4==T){DrugDat=read.csv(DrugFile$datapath, row.names =1 )}
    if(input$header4==F){DrugDat=read.csv(DrugFile$datapath)}
    return(DrugDat)
  })
  
  #AntibodyMap File
  AntiDat <- shiny:::reactive({
    AntibodyMapFile<-input$Antibody
  if (is.null(AntibodyMapFile))
    return(NULL)
  AntiDat <-read.csv(AntibodyMapFile$datapath, header = input$header1,stringsAsFactors = F )
   return(AntiDat)
  })
  
  #FS File
  FSDat <- shiny:::reactive({
    FSFile<-input$FsFile
  if (is.null(FSFile))
    return(NULL)
  FSDat <-read.csv(FSFile$datapath, header = input$header3,stringsAsFactors = F )
  return(FSDat)
  })
  
  #Global Signaling file
  SigDat <- shiny:::reactive({
    SigFile<-input$SigData
  if (is.null(SigFile))
    return(NULL)
  SigDat <-read.csv(SigFile$datapath, header = input$header2,stringsAsFactors = F )
  return(SigDat)
  })
  
```

## Set Parameters 

```{r}

  #TSCalcType
  TSCalcType <- shiny:::reactive({
  TSCalcType<-input$TSCalcType
  return(TSCalcType)
  })

  #filename
  fileName<-shiny:::reactive({
    fileName<-input$filename
    return(fileName)
    })
  
  #network algorithm
  NetworkAlgorithmn <-shiny:::reactive({
    NetworkAlgorithmn<-input$NetworkAlgorithmn
    return(NetworkAlgorithmn)})
    
  #nProt
  nProt<-shiny:::reactive({
    nProt<-ncol(DrugDat())
    return(nProt)
    })
  
  #nCond
  nCond<-shiny:::reactive({
    nCond<-nrow(DrugDat())
    return(nCond)
  })
  
  #Line
  nline<-shiny:::reactive({
    nline<-input$Line
    return(nline)
  })
```

# Run Target Score 

```{r example, message=FALSE, warning=FALSE}

 #choosing the way to construct reference network
NetworkInferred<-shiny:::reactive({
    NetworkAlgorithmn<-NetworkAlgorithmn()
    DrugDat<-DrugDat()
    AntiDat<-AntiDat()
    SigDat<-SigDat()
    nProt<-nProt()
    
  if (NetworkAlgorithmn=="Bio"){
    # reference network
    network=zeptosensPkg:::predictBioNetwork(nProt =nProt,proteomicResponses = DrugDat,antibodyMapFile = AntiDat)
    wk=network$wk
    wks <- network$wks
    dist_ind <- network$dist_ind
    inter <- network$inter
  }
  
  if(NetworkAlgorithmn=="Dat"){
    network=zeptosensPkg:::predictDatNetwork(data =SigDat,nProt=nProt,proteomicResponses=DrugDat)
    wk=network$wk
    wks <- network$wks
    dist_ind <- network$dist_ind
    inter <- network$inter
  }
  
  if(NetworkAlgorithmn=="Hyb"){
    # prior 
    wk=zeptosensPkg:::predictBioNetwork(nProt =nProt,proteomicResponses = DrugDat,maxDist = 1,antibodyMapFile = AntiDat)
    #Hyb
    network=zeptosensPkg:::predictHybNetwork(data =SigDat,prior=wk,nProt=nProt,proteomicResponses=DrugDat)
    
    wk=network$wk
    wks <- network$wks
    dist_ind <- network$dist_ind
    inter <- network$inter
  }
    NetworkInferred<-list(wk=wk,wks=wks,dist_ind=dist_ind,inter=inter)
    return(NetworkInferred)
  })

#Get FS Value
FsValue<-shiny:::reactive({
  DrugDat<-DrugDat()
  AntiDat<-AntiDat()
  nProt<-nProt()
    if(is.null(input$FsFile))
      {FsValue=zeptosensPkg:::getFsVals(nProt =nProt ,proteomicResponses =DrugDat,antibodyMapFile = AntiDat)}
    if(!is.null(input$FsFile))
      {FsValue=zeptosensPkg:::getFsVals(nProt =nProt ,proteomicResponses =DrugDat(),fsValueFile=FSDat,antibodyMapFile = AntiDat)}
return(FsValue)
  })
    
#Calc TargetScore
TargetScore<-shiny:::reactive({
  
  #call up reactive items
  NetworkInferred<-NetworkInferred()
  DrugDat<-DrugDat()
  nProt<-nProt()
  FsValue<-FsValue()
  fileName<-fileName()
  
  #give output filename
  targetScoreOutputFile <-paste0(fileName,"TS.txt")
  matrixWkOutputFile <-paste0(fileName,"wk.txt")
  signedMatrixWkOutputFile <-paste0(fileName,"wks.txt")
  
  #Network inferred
  wk=NetworkInferred$wk
  wks <- NetworkInferred$wks
  dist_ind <- NetworkInferred$dist_ind
  inter <- NetworkInferred$inter
  
  if(TSCalcType=="LinebyLine"){
      
      #Calc Std
      DrugDat[is.na(DrugDat)]<-0
      stdev <- zeptosensPkg:::sampSdev(nSample=nrow(DrugDat),nProt=ncol(DrugDat),nDose=1,nX=DrugDat)
      #normalization
      proteomicResponses<- DrugDat
      for(i in 1:nProt){
        for (j in 1:nrow(proteomicResponses)){
          proteomicResponses[j,i] <- (DrugDat[j,i]/stdev[i])      
        }
      }
      
      #Bootstrap in Getting TargetScore
      TS <- array(0,dim=c(nCond,nProt))
      TS.p <- array(0,dim=c(nCond,nProt))
      TS.q <- array(0,dim=c(nCond,nProt))
      
      nPerm=1000
      
      for(i in 1:nCond){
        
        results <- zeptosensPkg:::getTargetScore(wk=wk,
                                                 wks=wks,
                                                 dist_ind=dist_ind,
                                                 inter=inter,
                                                 nDose=1, 
                                                 nProt=nProt, 
                                                 proteomicResponses=proteomicResponses[i,], 
                                                 maxDist=maxDist, 
                                                 nPerm=nPerm,
                                                 cellLine=fileName, 
                                                 verbose=FALSE,fsFile=FsValue,
                                                 targetScoreOutputFile=targetScoreOutputFile, 
                                                 matrixWkOutputFile=matrixWkOutputFile,
                                                 targetScoreQValueFile="q.txt", 
                                                 targetScoreDoseFile="TS_d.txt",
                                                 targetScorePValueFile="p.txt")
        TS[i,]=results$ts
        TS.p[i,]=results$pts
        TS.q[i,]=results$q
      }
      colnames(TS)=colnames(DrugDat)
      rownames(TS)=rownames(DrugDat)

      colnames(TS.p)=colnames(DrugDat)
      rownames(TS.p)=rownames(DrugDat)

      colnames(TS.q)=colnames(DrugDat)
      rownames(TS.q)=rownames(DrugDat) 
  }
    TS.r<-list(TS=TS,TS.p=TS.p,TS.q=TS.q)
    return(TS.r)
})

#Get Heatmap for Drug Perturbation Data
output$heatmap <- shiny:::renderPlot({
  DrugFile <- input$DrugData
  if (is.null(DrugFile))
    return(NULL)
  if(input$header4==T)
  {DrugDat=read.csv(DrugFile$datapath, row.names =1 )}
  if(input$header4==F)
  {DrugDat=read.csv(DrugFile$datapath)}
  
  maxDat=max(as.matrix(DrugDat))
  minDat=min(as.matrix(DrugDat))
  bk <- c(seq(minDat,-0.01,by=0.01),seq(0,maxDat,by=0.01))
  data=as.matrix(DrugDat)
  pheatmap(data,
           scale = "none",
           color = c(colorRampPalette(colors = c("navy","white"))(length(seq(minDat,-0.01,by=0.01))),colorRampPalette(colors = c("white","firebrick3"))(length(seq(0,maxDat,by=0.01)))),
           legend_breaks=seq(minDat,maxDat,2),cellwidth = 2, cellheight = 2, fontsize=2, fontsize_row=2,
           breaks=bk)
})      


#Get heatmap for Calculated TS
output$TSheat <- shiny:::renderPlot({
       TS.r=TS.r()
       TS=TS.r$TS
       maxDat=max(as.matrix(TS))
       minDat=min(as.matrix(TS))
       bk <- c(seq(minDat,-0.01,by=0.01),seq(0,maxDat,by=0.01))
       data=as.matrix(TS)
       pheatmap(data,
                scale = "none",
                color = c(colorRampPalette(colors = c("navy","white"))(length(seq(minDat,-0.01,by=0.01))),colorRampPalette(colors = c("white","firebrick3"))(length(seq(0,maxDat,by=0.01)))),
                legend_breaks=seq(minDat,maxDat,2),cellwidth = 2, cellheight = 2, fontsize=2, fontsize_row=2,
                breaks=bk)
})


#Get Volcanoplot
  
output$volcanoplot <- shiny:::renderPlot({  
  TS.r=TS.r()
  nline=nline()
   TS=TS.r$TS[nline,]
   TS.q=TS$TS.q[nline,]
   TS<- as.matrix(TS)
   Padj<- as.matrix(TS.q)
# 
   if(nrow(Padj)!=nrow(TS)){
     stop("ERROR:Tag of TS and Qvalue does not match.")
   }
   tmpDat <- data.frame(cbind(TS,-1*log10(Padj)))
   colnames(tmpDat) <- c("TS","neglogQ")
#   
   color <- ifelse(Padj>0.4,"not significant","significant")
   rownames(color) <- rownames(TS)
   tmpDat$labelnames <-  row.names(tmpDat)
   sig01 <- subset(tmpDat, tmpDat$neglogQ > -1*log10(0.4))
   siglabel <- sig01$labelnames
   tmpDat$color <- color
#   
   ggplot() +
     geom_point(data=tmpDat, aes(x=TS, y=neglogQ, color=color), alpha=0.4, size=2) +
     theme_bw() +
     xlab("<TS>") + ylab("-log10 (Q-Value)") + ggtitle("")+
     scale_color_manual(name="", values=c("black", "red"))+
     geom_label_repel(data=sig01, aes(x=sig01$TS, y=sig01$neglogQ,label=siglabel), size=5)
 })

```

## Session Info

```{r, eval=FALSE}
sessionInfo()
```







