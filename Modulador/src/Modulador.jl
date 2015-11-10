###

module Modulador

using Images, Colors#, ImageView (en julia 0.4.0 ImageView genera muchos warnings (27oct15))
using FixedPointNumbers

export blazeMat, grayImage, grayImageCorr, monitor2, inicia, finaliza, thetaMat, faseMatInt, escalon, capturaImg, funBesselJ, rapidBesselJ, thetaMatInt #, canvas2ndScreen, monitor2canvas


#El contenido del archivo PrepMonit1 lo saqué del notebook 'Pruebas-003_(Imagenes)' en ~/Documentos/Cosas-Ijulia 
#run(`bash /home/atomosfrios/Documents/Cosas_Julia/LabAtomosFrios/Modulador/src/PrepMonit1`)
dir=joinpath(LOAD_PATH[length(LOAD_PATH)],"Modulador","src")
dir1=joinpath(dir,"PrepMonit1")
dir2=joinpath(dir,"PrepMonit2")
dir2canvas=joinpath(dir,"PrepMonit2canvas")
dir3=joinpath(dir,"PrepMonit3")
dir4=joinpath(dir,"imagen.png")
dir5=joinpath(dir,"PatronCorrector")

println("Bienvenido al módulo que controla el SLM.
    Para empezar utiliza la función inicia.
    ¡¡Recuerda correr la función finaliza al terminar tu sesión!!")
println("¿Qué long. de onda desea utilizar (1), (2), (3) ó (4)? \n 1 -> ninguna \n 2 -> 911 nm \n 3 -> 780 nm \n 4 -> 633 nm")
n=parse(Int64,readline())
const nombre_improbable_2pi=round(Int64, readcsv(joinpath(dir,"dospi"))[n])
const patronCorrector= (if n==1
                           zeros(Int64,600,800)
                        else
                           mod(  256-convert(Array{Int64,2}, map(reinterpret,    transpose([Colors.green(load(joinpath( dir5, filter(x->contains(x,"n$n"), readdir(dir5))[1] ))) ; zeros(FixedPointNumbers.UFixed{UInt8,8},8,600)])   ))  ,256)
                         end)



#Las siguientes funciones las saqué del notebook 'Pruebas-004_(generarImagenesGrises)' en ~/Documentos/Cosas-Ijulia 

#La función blazeMat da un arreglo de nVer × nHor enteros que representa una rejilla blaze. El tercer argumento que toma la función es el entero que representa la fase 2π y el cuarto argumento es el periodo (en pixeles).
#La función grayImage toma como argumento una matriz de enteros de nVer × nHor(como la que genera blazeMat) y la convierte en una imagen.

function blazeMat(cols::Integer, rengs::Integer, dosPi::Integer, periodo::Integer)
    matInt=zeros(Int64,rengs,cols)
    reng=mod( round(Int64,  1+(dosPi-1)*mod(round(Int64,linspace(0,cols-1,cols)),periodo)/(periodo-1)   ) , 256)
    for i=1:rengs
        matInt[i,:]=reng
    end
    mod(matInt,256)
    #convert(Array{FixedPointNumbers.UFixed{UInt8,8},2},   convert(Array{UInt8,2},matInt)    )
end
blazeMat(dosPi::Integer, periodo::Integer)=blazeMat(800, 600, dosPi, periodo)
blazeMat(periodo::Integer)=blazeMat(800, 600, nombre_improbable_2pi, periodo)



function grayImageCorr(matInt::Array{Int64,2},corr) # Toma matriz de Int64 y la convierte en una imagen 8-bits escala grises sumándole la corrección del modulador.
    if corr!=0
        matInt=mod(Modulador.patronCorrector+matInt,256)
    end
    mata3=convert(Array{UInt8,2}, matInt);
    matGray=convert(Array{ColorTypes.Gray{FixedPointNumbers.UFixed{UInt8,8}},2}, mata3)
    Image(matGray)
end
grayImageCorr(matInt::Array{Int64,2})=grayImageCorr(matInt,1) # Toma matriz de Int64 y la convierte en una imagen 8-bits escala grises sumándole la corrección del modulador.
grayImage(matInt::Array{Int64,2})=grayImageCorr(matInt,0) # Toma matriz de Int64 y la convierte en una imagen 8-bits escala grises.
#function grayImage(matUInt::Array{FixedPointNumbers.UFixed{UInt8,8},2}) # Igual que anterior pero matriz de UFixed{UInt8,8}
#    matGray=convert(Array{ColorTypes.Gray{FixedPointNumbers.UFixed{UInt8,8}},2}, matUInt)
#    Image(matGray)
#end

#Images.imwrite(grayImage(ones(Int64,600,800)),dir4) # guarda imágen en blanco para proyectar en modulador al iniciar.
save(dir4,grayImage(ones(Int64,600,800)))




function inicia()
    #El siguiente run es para preparar el 2do monitor (colocación, resolución y orientación)    
    run(`bash $(Modulador.dir1)`)
    sleep(3)
    #El siguiente run es para abrir EOG en 2do monitor Fullscreen  
    run(`bash $(Modulador.dir2)`)
    sleep(2)
    ##### Esto es para versión con Eye of Gnome 
    spawn(`eog --fullscreen $dir4 &`)
    ##### Esto es para versión con Eye of Gnome 
end


function monitor2(imagen::Image)
    ##### Esto es para versión con Eye of Gnome
    if size(imagen.data)==(600,800)
        #Images.imwrite(imagen,dir4)
        save(dir4,imagen)
    else
        error("Deben ser imágenes de 800x600")
    end
    sleep(1.1) # esto es para que le dé tiempo de guardar y cambiar la imagen en eog Viewer
    return nothing  
end

function finaliza()
    #Images.imwrite(grayImage(ones(Int64,600,800)),dir4)
    save(dir4,grayImage(ones(Int64,600,800)))
    run(`bash $(Modulador.dir3)`)
end


##### Esto es para versión con Canvas (no fullscreen, en julia 0.4.0 no sirve ImageView (27oct15))
#run(`bash $dir2canvas`)
#const canvas2ndScreen=ImageView.view(grayImage(ones(Int64,800,600)))   
    # Esta constante es el canvas (imagen) del segundo monitor, por lo que los run son para abrirlo en el 2do monitor

#function monitor2canvas(imagen::Image)    
#    ImageView.view(canvas2ndScreen[1],imagen)
#end
##### Esto es para versión con Canvas (no fullscreen, en julia 0.4.0 no sirve ImageView (27oct15))




### Las siguientes funciones las saqué del notebook 'Pruebas-006_(generarEstructuraHaces).ipynb' en ~/Documentos/Cosas-Ijulia

function thetaMat(th) # th son los grados por los cuales se puede rotar el holograma
    # esta función da una matriz cuyas entradas representan los ángulos (van de -π a π)
    # recuerda que la convención para matrices es invertir eje Y, por eso valores negativos quedan arriba
    x=round(Int64, ones(600)*linspace(-399,400,800)' )
    y=round(Int64, linspace(-299,300,600)*ones(800)' )
    xp=cos(th*π/180)*x-sin(th*π/180)*y # rotacion
    yp=sin(th*pi/180)*x+cos(th*pi/180)*y
    atan2(yp,xp) 
end
thetaMat()=thetaMat(0)

function faseMatInt(z::Matrix,gray2pi::Int64,gray0::Int64)
    # A esta función le das como argumento una matriz cualquiera y la convierte en una 
    # matriz con entradas Int64 con valores que van desde gray0 hasta gray2pi
    if gray0<1 || gray0>256
        error("gray0 debe estar entre 1 y 256")
    end
    if gray2pi<1 || gray2pi>256
        error("gray2pi debe estar entre 1 y 256")
    end
    if gray2pi<gray0
        error("gray2pi debe ser mayor o igual que gray0")
    end
    #notemos que Gray{Ufixed8}(256)==Gray{Ufixed8}(0) -> true
    z=(z-minimum(z))/(maximum(z-minimum(z))) # Normalizo de 0 a 1
    z=((z)*(gray2pi-gray0)) #Renormalizo min=0 max=255
    z=mod(z,256)+gray0 #Obtengo módulo, ahora min=gray0 y max=gray2pi
    return(round(Int64,z)) # finalmente convierto a enteros 
end
faseMatInt(z::Matrix)=faseMatInt(z,nombre_improbable_2pi,1) # si no especificas normaliza de 1 a nombre_improbable_2pi (gama entera de grises)
faseMatInt(z::Matrix,gray2pi::Int64)=faseMatInt(z,gray2pi,1) # puedes solo especificar el tope superior

function escalon(nVer::Integer, nHor::Integer, fondo::Integer, dosPi::Integer, periodo::Integer)
    if fondo<1 || fondo>256
        error("fondo debe estar entre 1 y 256")
    end
    if dosPi<1 || dosPi>256
        error("dosPi debe estar entre 1 y 256")
    end
    if dosPi<fondo
        error("dosPi debe ser mayor o igual que fondo")
    end
    matInt=zeros(Int64,nHor,nVer)
    red=fondo+(dosPi-fondo)*round(Int64,mod(round(Int64,linspace(1,nVer,nVer))-1,periodo)/(periodo))
    for i=1:nHor
        matInt[i,:]=red
    end
    mod(matInt,256)
    #convert(Array{FixedPointNumbers.UFixed{UInt8,8},2},   convert(Array{UInt8,2},matInt)    )
end
escalon(fondo::Integer, dosPi::Integer, periodo::Integer)=escalon(800,600,fondo,dosPi,periodo)
escalon(dosPi::Integer, periodo::Integer)=escalon(800,600,1,dosPi,periodo)
escalon(periodo::Integer)=escalon(800,600,1,nombre_improbable_2pi,periodo)

### La siguiente función es para calibrar el SLM (no la exporto para no usarla cuando no es necesario)
# Lo que hace es tomar una foto para cada nivel de la función escalón, luego se fija en la diferencia entre estas fotos
# para saber con qué valor se regresa a la fase original (+2pi)
dirCal=joinpath(LOAD_PATH[length(LOAD_PATH)],"Modulador","calib")
function calibrar()
    println("Recuerda correr 'finalizaCalib()' al final para borrar imágenes")
    println("Al finalizar la calibración debes reiniciar Julia para que se tomen en cuenta los cambios")
    calibrarAux()
    dir7=joinpath(dirCal,string(now()))
    ima1=float(Images.green(Images.data(Images.load(dir7*"--1.jpeg"))))
    ima2=similar(ima1)
    lista=zeros(256)
    #lista=Array{Float64,2}[]
    for i=2:256
        ima2=float(Images.green(Images.data(Images.load(dir7*"--$i.jpeg"))))
        lista[i]=sum(abs(ima1-ima2))
    end
    nuevo2pi=length(lista)+1-findmin(reverse(lista))[2] # Lo recorro al revés para obtener el mínimo más alejado
    f=open(joinpath(dir,"dospi"),"a") #abro archivo en modo append
    write(f,"$(nuevo2pi) # "*string(now())*"\n")
    close(f)    
    return lista
end
function calibrarAux()
    for i=1:256
        monitor2(grayImage(escalon(i,10))) #Este periodo permite ver los órdenes 0,1,2 en un CCD de webcam común
        capturaImg2(i)
    end
end
function finalizaCalib()
    dir8=joinpath(dirCal,".finalCalib")
    f=open(dir8,"w") #abro archivo en modo write (sebreescribe lo que este)
    dir9=joinpath(dirCal,"*--*.jpeg")
    write(f,"rm $(dir9)")
    close(f)
    run(`bash $(dir8)`)
end

### La siguiente función es para capturar imágenes, para configuración ver Modulador/src/webcamConfig
function capturaImg2(n::Integer) #ojo, esta solo sirve para calibrar, usa únicamente el otro método
    dir5=joinpath(dir,"webcamConfig")
    dir6=joinpath(dirCal,string(now())*"--$n.jpeg")
    run(`fswebcam -c $(dir5) --save $(dir6)`)
end
dirCap=joinpath(LOAD_PATH[length(LOAD_PATH)],"Modulador","capturas")
function capturaImg()
    dir5=joinpath(dir,"webcamConfig")
    dir6=joinpath(dirCap,string(now())*".jpeg")
    run(`fswebcam -c $(dir5) --save $(dir6)`)
end



### Lo siguiente es para incluir función Bessel, lo seaqué del notebook 'Pruebas-006_(generarEstructuraHaces)'
function funBesselJ(n,l,w,th)
    x=round(Int64, ones(600)*linspace(-399,400,800)')
    y=round(Int64, linspace(-299,300,600)*ones(800)')
    xp=cos(th*π/180)*x-sin(th*π/180)*y # rotacion
    yp=sin(th*pi/180)*x+cos(th*pi/180)*y
    besselj(n,sqrt((xp.^2+yp.^2)/w^2)) .* exp(l*1im*atan2(yp,xp))
end
funBesselJ(n,l,w)=funBesselJ(n,l,w,0)

function rapidBesselJ(n,l,w,th)
    faseMatInt(angle(funBesselJ(n,l,w,th)))
end
function rapidBesselJ(n,l,w)
    faseMatInt(angle(funBesselJ(n,l,w)))
end



### Lo siguiente es para darle vórtice al haz para (junto con axicón) generar el Bessel
function thetaMatInt(n,th)
    matInt=mod(n*(faseMatInt(thetaMat(th))-1),nombre_improbable_2pi)+1
    mod(matInt,256)
end
thetaMatInt(n)=thetaMatInt(n,0)

end
