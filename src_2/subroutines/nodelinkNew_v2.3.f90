MODULE NODELINKMOD
IMPLICIT NONE
  
  TYPE :: NODELINKTYP
    INTEGER(KIND=4)::CS1
    INTEGER(KIND=4),ALLOCATABLE::CELL(:,:)
    INTEGER(KIND=4)::CELLX,CELLY,CELLZ,CELLN
    REAL(KIND=8)::REFBL(3),REFTR(3),CELLR
  CONTAINS
    PROCEDURE :: INITCELL
    PROCEDURE :: FILLCELL
    PROCEDURE :: FINDCELL
    PROCEDURE :: ENDCELL
  END TYPE NODELINKTYP

CONTAINS

  SUBROUTINE INITCELL(THIS,CELX,CELY,CELZ,I)
  IMPLICIT NONE

    CLASS(NODELINKTYP),INTENT(INOUT)::THIS
    INTEGER(KIND=4),INTENT(IN)::CELX,CELY,CELZ,I

    THIS%CELLX=CELX+2
    THIS%CELLY=CELY+2
    THIS%CELLZ=CELZ+2
    THIS%CELLN=THIS%CELLX*THIS%CELLY*THIS%CELLZ
    THIS%CS1=I
    ALLOCATE(THIS%CELL(0:THIS%CELLN-1,0:THIS%CS1))        

  END SUBROUTINE INITCELL

  SUBROUTINE FILLCELL(THIS,NP,CX,CY,CZ,INCELLR,CP1,CP2)
  IMPLICIT NONE    
    
    CLASS(NODELINKTYP),INTENT(INOUT)::THIS
    INTEGER(KIND=4),INTENT(IN)::NP
    REAL(KIND=8),INTENT(IN)::CX(NP),CY(NP),CZ(NP),INCELLR
    REAL(KIND=8),INTENT(IN)::CP1(3),CP2(3) !! BOTTOMLEFT AND TOPRIGHT CORNER

    INTEGER(KIND=4)::IX,IY,IZ,I,J,K,L,IPOS,INUM

    !WRITE(8,'(" [MSG] ENTERING FILLCELL")')

    THIS%REFBL=CP1
    THIS%REFTR=CP2
    THIS%CELLR=INCELLR

    IX = FLOOR( (THIS%REFTR(1)-THIS%REFBL(1)) / THIS%CELLR )
    IY = FLOOR( (THIS%REFTR(2)-THIS%REFBL(2)) / THIS%CELLR )
    IZ = FLOOR( (THIS%REFTR(3)-THIS%REFBL(3)) / THIS%CELLR )
    IF((IX.GT.THIS%CELLX).OR.(IY.GT.THIS%CELLY).OR.&
      (IZ.GT.THIS%CELLZ))THEN
      WRITE(8,'(" [ERR] INCREASE CELLX OR CELLY OR CELLZ")')
      WRITE(8,'(" [---] LIMITS ",3I10)')THIS%CELLX,THIS%CELLY,&
        THIS%CELLZ
      WRITE(8,'(" [---] ACTUAL ",3I10)')IX,IY,IZ
      STOP
    ENDIF    

    THIS%CELL(:,0)=0
    DO I=1,NP
      IX=FLOOR( (CX(I)-THIS%REFBL(1)) / THIS%CELLR )
      IY=FLOOR( (CY(I)-THIS%REFBL(2)) / THIS%CELLR )
      IZ=FLOOR( (CZ(I)-THIS%REFBL(3)) / THIS%CELLR )

      IF(IX.LT.0)IX=0
      IF(IY.LT.0)IY=0
      IF(IZ.LT.0)IZ=0
      IF(IX.GE.THIS%CELLX)IX=THIS%CELLX-1
      IF(IY.GE.THIS%CELLY)IY=THIS%CELLY-1
      IF(IZ.GE.THIS%CELLZ)IZ=THIS%CELLZ-1
      IPOS=IX+IY*THIS%CELLX+IZ*THIS%CELLY*THIS%CELLX

      INUM=THIS%CELL(IPOS,0)+1
      IF(INUM.GT.THIS%CS1)THEN
        WRITE(8,'(" [ERR] INCREASE CS1 FOR CELL")')
        WRITE(8,'(" [---] LIMITS ",I10)')THIS%CS1
        WRITE(8,'(" [---] CELL ",3I10)')IX,IY,IZ        
        STOP
      ENDIF
      THIS%CELL(IPOS,0)=INUM
      THIS%CELL(IPOS,INUM)=I
    ENDDO    

    !WRITE(8,'(" [MSG] EXITING FILLCELL")')

  END SUBROUTINE FILLCELL

  SUBROUTINE FINDCELL(THIS,CX,CY,CZ,IX,IY,IZ,IPOS)
  IMPLICIT NONE

    CLASS(NODELINKTYP),INTENT(IN)::THIS
    REAL(KIND=8),INTENT(IN)::CX,CY,CZ
    INTEGER(KIND=4),INTENT(OUT)::IX,IY,IZ,IPOS

    IX=FLOOR((CX-THIS%REFBL(1))/THIS%CELLR)
    IY=FLOOR((CY-THIS%REFBL(2))/THIS%CELLR)
    IZ=FLOOR((CZ-THIS%REFBL(3))/THIS%CELLR)

    IF(IX.LT.0)IX=0
    IF(IY.LT.0)IY=0
    IF(IZ.LT.0)IZ=0
    IF(IX.GE.THIS%CELLX)IX=THIS%CELLX-1
    IF(IY.GE.THIS%CELLY)IY=THIS%CELLY-1
    IF(IZ.GE.THIS%CELLZ)IZ=THIS%CELLZ-1
    IPOS=IX+IY*THIS%CELLX+IZ*THIS%CELLY*THIS%CELLX

  END SUBROUTINE FINDCELL

  SUBROUTINE ENDCELL(THIS)
  IMPLICIT NONE

  CLASS(NODELINKTYP),INTENT(INOUT)::THIS

  DEALLOCATE(THIS%CELL)

  END SUBROUTINE ENDCELL

END MODULE NODELINKMOD



SUBROUTINE NODELINK_3_SHA(MLDOM,LNODE,NODN,SCALE,DDL,DDR,&
  NODEID,NWALLID,COORX,COORY,COORZ)
USE MLPGKINE
USE NEIGHNODES
USE NODELINKMOD      
!INCLUDE 'COMMON.F'
IMPLICIT NONE

  TYPE(NODELINKTYP),INTENT(IN)::MLDOM
  INTEGER,PARAMETER::IDSZ=3000
  INTEGER(KIND=4),INTENT(IN)::NODN,NODEID(-2:NODN),LNODE
  INTEGER(KIND=4),INTENT(IN)::NWALLID(LNODE,4)
  REAL(KIND=8),INTENT(OUT)::DDR(NODN)
  REAL(KIND=8),INTENT(IN)::SCALE,DDL
  REAL(KIND=8),INTENT(IN)::COORX(LNODE),COORY(LNODE),COORZ(LNODE)
  REAL(KIND=8)::DIS(IDSZ),DX,DY,DZ,DR,CX,CY,CZ,DISWK(IDSZ),COFF,DS      
  REAL(KIND=8)::CIRCLE_WATER,CIRCLE_WALL,CIRCLE_S_WALL
  REAL(KIND=8)::RIAV
  INTEGER::IWORK(200),ISORTD(IDSZ)
  INTEGER::IN12(IDSZ),IDW(IDSZ)  
  INTEGER::INWK(IDSZ)
  INTEGER(KIND=4)::I,J,K,IX,IY,IZ,IPOS,KK,IX1,IY1,IZ1,IK,IN

  WRITE(8,'(" [MSG] ENTERING NODELINK_3_SHA")')

  DDR=DDL

  CIRCLE_WATER=3.D0*DDL  !DOMAIN OF WATER PARTICLES
  CIRCLE_WALL= 4.2D0*DDL !4.2D0*DDL   !DOMAIN OF WALL PARTICLES
  CIRCLE_S_WALL= 4.5D0*DDL !4.5D0*DDL   !DOMAIN OF WALL PARTICLES 


  !$OMP PARALLEL DEFAULT(SHARED) PRIVATE(I,RIAV,IX,IY,IZ,IPOS,&
  !$OMP&  KK,IX1,IY1,IZ1,IK,IN,DR,IN12,DIS,ISORTD,IDW,COFF,DS)
  !$OMP DO SCHEDULE(DYNAMIC,100)
  DO I=1,NODN
    IF(I.LE.NODEID(-2))RIAV=CIRCLE_WATER
    IF(I.GT.NODEID(-2))RIAV=CIRCLE_WALL
    IF(I.GT.NODEID(-2).AND.NWALLID(I,3).EQ.9)THEN
      RIAV=CIRCLE_S_WALL
    ENDIF

    CALL MLDOM%FINDCELL(COORX(I),COORY(I),COORZ(I),&
      IX,IY,IZ,IPOS)
    KK=0

    DO IX1=IX-1,IX+1
      DO IY1=IY-1,IY+1
        DO IZ1=IZ-1,IZ+1

          IF((IX1.GE.0.AND.IX1.LT.MLDOM%CELLX).AND.&
            (IY1.GE.0.AND.IY1.LT.MLDOM%CELLY).AND.&
            (IZ1.GE.0.AND.IZ1.LT.MLDOM%CELLZ))THEN

            IPOS=IX1+IY1*MLDOM%CELLX+IZ1*MLDOM%CELLY*MLDOM%CELLX
            DO IK=1,MLDOM%CELL(IPOS,0)
              IN=MLDOM%CELL(IPOS,IK)
              IF(IN.NE.I)THEN
                DR=DSQRT((COORX(IN)-COORX(I))**2 +&
                  (COORY(IN)-COORY(I))**2 +&
                  (COORZ(IN)-COORZ(I))**2)
                IF(DR.GT.RIAV) CYCLE
                KK=KK+1
                IF(KK.GT.IDSZ) GOTO 111
                IN12(KK)=IN
                DIS(KK)=DR
              ENDIF                                    
            ENDDO
          ENDIF
        ENDDO
      ENDDO
    ENDDO

111 IF(KK.GT.IDSZ)THEN
      WRITE(8,'(" [ERR] INCREASE IDSZ")')
      STOP
    ENDIF

    IF(ALLOCATED(NLINK(I)%I)) DEALLOCATE(NLINK(I)%I)
    IF(KK.EQ.0)THEN
      IF(NODEID(I).GE.0)THEN
        WRITE(8,*)'[ERR] FATAL ERROR, KK=0',I,NODEID(I)
        WRITE(8,*)COORX(I),COORY(I),COORZ(I)
        WRITE(8,*)IX,IY,IZ
      ENDIF          
      ALLOCATE(NLINK(I)%I(0:KK))
      !STOP
      GOTO 25
    ENDIF

    CALL SORT2(DIS(1:KK),ISORTD(1:KK),IDW(1:KK),KK)
    ALLOCATE(NLINK(I)%I(0:KK))
    DO IX=1,KK
      IY=ISORTD(IX)
      NLINK(I)%I(IX) = IN12(IY)
    ENDDO
25  NLINK(I)%I(0) = KK

    IF (KK.LT.6) THEN
      WRITE(8,'(a16,3I10)')'ERROR IN SORTD',I,KK,NODEID(I)
      WRITE(8,'(a16,3F10.5)')'______________',&
      COORX(I),COORY(I),COORZ(I)
    ENDIF        

    COFF= 0.25D0 !0.1d0  !0.25D0
    DS=0D0
    IF(KK.LE.3)THEN 
      DS=DDL         
    ELSEIF(KK.LT.6)THEN
      DO IX=1,KK
        DS=DS+DIS(ISORTD(IX))
      ENDDO
      DS=1D0*DS/KK
    ELSE
      DO IX=1,6
        DS=DS+DIS(ISORTD(IX))
      ENDDO
      DS=DS/6D0
    ENDIF

    DDR(I)=DS*(COFF+SCALE)
    R0(I)=DS*COFF
    R(I)=DS*SCALE
                
    !R(I)=MIN(SCALE*DS,RMAX) !06/01/2006 !
    ! R(I)=MIN(SCALE*DIS(ISORTD(4)),RMAX) !06/01/2006

    ! IF (R(I).LT.(RMAX/SCALE)) R(I)=RMAX/SCALE !ADDED ON 28/12/2005

    ! R0(I)=COFF*DDL  
    ! R(I)=SCALE*DDL 

    !! Shagun change : Multiplying the radius with a multiplier
    R(I)=R(I)


    !CC(I)=DIS(ISORTD(5)) !DIS(ISORTD(5)) 
    CC(I)=DDR(I)

  ENDDO
  !$OMP END DO NOWAIT
  !$OMP END PARALLEL

  WRITE(8,'(" [MSG] EXITING NODELINK_3_SHA")')
  WRITE(8,*)
END SUBROUTINE NODELINK_3_SHA