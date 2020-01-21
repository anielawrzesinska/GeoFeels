install.packages("devtools")
devtools::install_github("ropensci/geojsonio")
library("geojsonio")
library(tidytext)
library(tidyr)
library(dplyr)
library(sp)
library(sf)
library(purrr)
library(GISTools)
library(raster)
library(lattice)
library(rgdal)

paleta = c("#0047CC", "#7A92CC", "#FCFCFC", "#FFE77F", "#FFC700")

uklad_usa<-"+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
uklad_pl<-"+proj=tmerc +lat_0=0 +lon_0=19 +k=0.9993 +x_0=500000 +y_0=-5300000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"

slownik_pl<-read.csv2("D:/inzynier/data/sentyment_pl.csv")
slownik_en<-get_sentiments("bing")

month<-"11_2019"
country<-"usa" #polska/usa
months<- c("08_2019","09_2019", "10_2019", "11_2019")

if(country=="polska")
{
  uklad<-uklad_pl
  slownik<-slownik_pl}else
{
  uklad<-uklad_usa
  slownik<-slownik_en}

#---------------------wczytanie granic Polski i USA----------------------------------------------------------------------
polska=read_sf(dsn="D:/inzynier/data/polska.gpkg")
polska_sp<-as(polska,'Spatial')

usa84 = read_sf(dsn = "D:/inzynier/data/ameryka.gpkg")
usa <- st_transform(usa84,uklad_usa)

#------------------------------------tworzenie siatek ------------------------------------------------------------------
Hex <- st_make_grid(usa, cellsize=80000, square = FALSE)
grid = st_sf(data.frame(a=1:length(Hex), geom=Hex))
hex_sp_usa<-as(grid,'Spatial')

Hex <- st_make_grid(polska, cellsize=20000, square = FALSE)
grid = st_sf(data.frame(a=1:length(Hex), geom=Hex))
hex_sp_pl<-as(grid,'Spatial')

if(country=="polska")
{
 hex_sp<-hex_sp_pl
 area<- poly.areas(hex_sp)}else
  {
    hex_sp<-hex_sp_usa
    area<- poly.areas(hex_sp)}
#-----------------------------------wczytanie geojsona-----------------------------------------------------
#for (month in months)
#{
lista_plikow<-Sys.glob(paste("D:/inzynier/data/",month,"/geodata/",country,"/*.json",sep=""))

for (plik in lista_plikow)
{
  nazwa_pliku<-substr(plik, nchar(plik)-14, nchar(plik)-5)
  data_geojson <- geojson_read(plik, what = "sp")
  data_json<- spTransform(data_geojson,CRS(uklad))

  if(country=="polska")
  data_json<- intersect(data_json,polska_sp)

  data_json$positive=0
  data_json$negative=0

#-----------------------------------------------------sentyment---------------------------------------------------------------------------------------


  for(i in 1:length(data_json))
  {
    text<-data_json@data$text[i]
    text <- gsub("\\$", "", text)
    tokens <- data_frame(text = text) %>% unnest_tokens(word, text)
    sentiment<-tokens %>% inner_join(slownik) %>% count(sentiment) %>%
      spread(key=sentiment, value=n, fill = 0)
  
    if(length(sentiment)==0 || colnames(sentiment)=="<NA>")
    {data_json@data$negative[i]<-0
    data_json@data$positive[i]<-0}
    else
    {
    
      if(colnames(sentiment) %>% has_element("positive")&& colnames(sentiment) %>% has_element("negative")) 
      {
        data_json@data$negative[i]<-sentiment$negative
        data_json@data$positive[i]<-sentiment$positive
      
      
      }
      else
      {
        if(colnames(sentiment)=="positive") 
        {
          data_json@data$positive[i]<-sentiment$positive
          data_json@data$negative[i]<-0
        }
        else
        {
        
          data_json@data$negative[i]<-sentiment$negative
          data_json@data$positive[i]<-0
        }   
      }
    }
  }

  data_json$sentyment<-data_json$positive-data_json$negative

#-----------------------------------------------------odds ratio--------------------------------------------------------------------------------

  tw_positive <-data_json[data_json$sentyment>0,]
  tw_negative <-data_json[data_json$sentyment<0,]

  count <- poly.counts(data_json,hex_sp)

  odds <-as.data.frame(((poly.counts(tw_positive,hex_sp)-poly.counts(tw_negative,hex_sp))/(length(tw_positive)+length(tw_negative)))/(poly.counts(data_json,hex_sp)/nrow(data_json)))
  colnames(odds)<-c("odds_ratio")
  odds$id=1:nrow(odds)
  odds_ratio<- merge(hex_sp,odds, by.x='a', by.y='id')
  odds_ratio[is.nan(odds_ratio$odds_ratio)]<-0
  
  writeOGR(odds_ratio,paste("D:/inzynier/data/",month,"/warstwy/",country,"/",nazwa_pliku,".gpkg",sep=""),nazwa_pliku, driver="GPKG")
}
#}
#-----------------------------------------rysowanie mapy-----------------------------------------------------------------------------------
#tworzenie skali

list_odds<-list()
y=1

for (month in months)
{lista_plikow<-Sys.glob(paste("D:/inzynier/data/",month,"/warstwy/",country,"/*.gpkg",sep=""))
for (plik in lista_plikow)
{
  
  
  warstwa=read_sf(dsn=plik)
  
  for(i in 1:nrow(warstwa))
  {
    
    list_odds[y] <-warstwa$odds_ratio[i]
    y=y+1
  }
  
  
}}

lst2 <- unlist(list_odds, use.names = FALSE)
std<-sd(lst2)

  

#rysowanie map
for (month in months)
  {lista_plikow<-Sys.glob(paste("D:/inzynier/data/",month,"/warstwy/",country,"/*.gpkg",sep=""))
  for (plik in lista_plikow)
  {
    nazwa_pliku<-substr(plik, nchar(plik)-14, nchar(plik)-5)
     warstwa=read_sf(dsn=plik)
    if(country=="polska")
    wynik<-st_intersection(warstwa, polska) else
    wynik<-st_intersection(warstwa, usa)
    
    wynik<-as(wynik,'Spatial')
  
    wynik$odds_ratio_fac<- cut(wynik$odds_ratio,c(minimum-0.01,0-(2*std),0-std,0+std,0+(2*std),maksimum+0.01))
  png(file=paste("D:/inzynier/data/",month,"/mapy/",country,"/",nazwa_pliku,".png",sep=""), bg="white", width=1024, height = 768)
  print(spplot(wynik,zcol="odds_ratio_fac",col.regions=paleta, col="#CCCCCC", main=list(label=nazwa_pliku, cex=3), colorkey = list(labels = list( labels = c("very negative", "negative","neutral","positive","very positive"),        
                                                                                                                                               width = 2, cex = 1.5))))
  dev.off()
  
  
}}
