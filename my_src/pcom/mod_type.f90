
! Description: data-type definition
!
!      Author: OU Yuyuan <ouyuyuan@lasg.iap.ac.cn>
!     Created: 2015-02-26 08:20:12 BJT
! Last Change: 2016-05-13 09:45:01 BJT

module mod_type

  use mod_kind, only: sglp, wp

  implicit none
  private

  public &
    type_mat, &
    type_time, &
    tctr, &
    type_gi, &
    type_gj, &
    type_gij, &
    type_gvar_r2d, &
    type_gvar_r3d, &
    type_gvar_m2d, &
    type_gvar_m3d, &
    type_frc, &
    type_bnd, &
    type_bintgu, &
    type_ch, &
    type_accu_gm3d, &
    type_accu_gr3d, &
    type_accu_gr2d, &
    operator(+), &
    operator(<), &
    type_print, &
    type_days_month, &
    type_days_year, &
    type_str2sec, &
    type_str2time

  ! matrix structure !{{{1
  ! for horizontal (u,v) and tracer (theta,s)
  type :: type_mat
    real (kind=wp) :: x(2)
  end type type_mat

  ! time structure !{{{1
  ! yyyy-mm-dd hh:mm:ss
  type :: type_time
    integer :: y, m, d, h, mi, s
    integer :: mm ! maxima day of the current month
  end type type_time

  ! integration time control !{{{1
  type :: type_tctr
    type (type_time) :: pt, ct ! time of previous/current baroclinic step
    real (kind=wp)   :: t1, t2 ! mpi time barrier
    integer*8        :: nt     ! total baroclinic time steps
    integer*8        :: i      ! current baroclinic time steps
  end type
  type (type_tctr) :: tctr

  ! horizontal stagger grid  !{{{1
  type :: type_gi
    integer :: n ! grid number
    integer :: i, j ! x/y position of (i,j) grid
    ! rescaled Lame coefficients, h1 / a
    !   rh2 and h3 is 1 for current version of pcom
    real (kind=wp), allocatable :: rh(:,:)
    real (kind=wp), allocatable :: tn(:,:) ! tan( lat )
    ! coordinate increaments
    type (type_mat), allocatable :: dx(:,:)
    ! north-south / east-west / diagonal neighbors
    type (type_gi), pointer :: ns, ew, di
  end type type_gi

  type :: type_gj
    integer :: n
    integer :: k
    ! m, grid thickness
    real (kind=wp), allocatable :: dz(:)
    ! pa, vertical coordinate increments
    real (kind=wp), allocatable :: dpr(:)
    ! m, geometry height
    real (kind=wp), allocatable :: z(:)
    ! Pa, pressure, vertical coordinate
    real (kind=wp), allocatable :: pr(:)
    type (type_gj), pointer :: ud ! up/down neighbor grid
  end type type_gj

  type :: type_gij
    integer, allocatable :: msk(:,:,:)
    integer, allocatable :: lev(:,:)
    ! initial geopotential height at sea bottom
    real (kind=wp), allocatable :: phih(:,:)
    ! initial pressure at sea bottom (exclude atmopheric pressure)
    real (kind=wp), allocatable :: prh(:,:)
    type (type_gij), pointer :: ns, ew, di, ud
    type (type_gi),  pointer :: hg
    type (type_gj), pointer :: vg
  end type type_gij

  ! grid variables !{{{1

  type type_gvar_r2d
    real (kind=wp), allocatable :: v(:,:) ! data values
    type (type_gi), pointer :: hg
  end type type_gvar_r2d

  type type_gvar_r3d
    real (kind=wp), allocatable :: v(:,:,:) ! data values
    type (type_gij), pointer :: g
  end type type_gvar_r3d

  type type_gvar_m2d
    type (type_gvar_r2d) :: x(2)
  end type type_gvar_m2d

  type type_gvar_m3d
    type (type_gvar_r3d) :: x(2)
  end type type_gvar_m3d

  ! compound variables !{{{1

  ! forcing
  type :: type_frc
    type (type_gvar_m3d) :: tau ! wind stress (taux, tauy)
    type (type_gvar_m3d) :: ts  ! climatic mean surface (temp., salinity)
    type (type_gvar_r3d) :: pa  ! sea level atmospheric pressure
    type (type_gvar_r3d) :: fw  ! fresh water flux (evaporation - precp.)
  end type type_frc

  ! surface boundary
  type :: type_bnd
    type (type_gvar_m2d) :: tau
    type (type_gvar_m2d) :: ts
    type (type_gvar_r2d) :: pa
    type (type_gvar_r2d) :: fw
  end type type_bnd

  ! barotropic integration at g32
  type :: type_bintgu 
    ! north/south of g22 at g32
    real (kind=wp), allocatable, dimension(:,:) :: xn, xs 
    ! east / west of g42 at g32
    real (kind=wp), allocatable, dimension(:,:) :: ye, yw 
  end type type_bintgu

  ! normalized sea bottom pressure when using stagger time scheme
  type :: type_ch
    real (kind=wp), allocatable :: tp(:,:) ! previous time step values
    real (kind=wp), allocatable :: tc(:,:) ! current  time step values
    ! mean values in 1 baroclinic step ( = pbt_st(:,:,2) of v1.0 )
    real (kind=wp), allocatable :: bc(:,:) 
    ! mean values in 2 baroclinic step ( = pbt_st(:,:,3) of v1.0 )
    real (kind=wp), allocatable :: bc2(:,:)
    type (type_gi), pointer :: hg
  end type type_ch

  ! accumulated variables !{{{1
  ! for time-average output
  type :: type_accu_gm3d
    type (type_gvar_m3d) :: var
    integer :: n, nrec
  end type type_accu_gm3d

  type :: type_accu_gr3d
    type (type_gvar_r3d) :: var
    integer :: n, nrec
  end type type_accu_gr3d

  type :: type_accu_gr2d
    type (type_gvar_r2d) :: var
    integer :: n, nrec
  end type type_accu_gr2d

  !interface !{{{1

  interface operator(+)
    module procedure time_plus_integer
  end interface

  interface operator(<)
    module procedure time_lt_string
  end interface

  interface type_print
    module procedure print_type_time
    module procedure print_i3d
    module procedure print_i2d
    module procedure print_r3d
    module procedure print_r2d
    module procedure print_r1d
  end interface

contains !{{{1

subroutine print_r3d (var) !{{{1
! print 3d reall array in a nice way
  
  real (kind=wp) :: var(:,:,:)
  integer :: ni, nj, nk, i, j, k

  ni = size(var, 1)
  nj = size(var, 2)
  nk = size(var, 3)

  do k = 1, nk
    do i = 1, ni
      write(*,'(100f5.1)') var(i,:,k)
    end do
    write(*,*) ''
  end do
  
end subroutine print_r3d

subroutine print_r2d (var, opt) !{{{1
! print 2d array in a nice way
  
  real (kind=wp) :: var(:,:)
  character (len=*), optional :: opt ! print boundary 

  integer :: ni, nj, i, j

  ni = size(var, 1)
  nj = size(var, 2)

  if ( present(opt) )then

    ! print east west boundary
    if ( opt .eq. 'ew' ) then
      do i = 2, ni - 1
        write(*,'(2e7.1e1, a, 2e7.1e1)') &
          var(i,1), var(i,2), ' . . . ', var(i,nj-1), var(i,nj)
      end do
    ! print north south
    else if ( opt .eq. 'ns' ) then
      write(*,'(a,i2, a, 100e7.1e1)') &
        'row = ', 1, ', ', var(1,2:nj-1)
      write(*,'(a,i2, a, 100e7.1e1)') &
      'row = ', 2, ', ', var(2,2:nj-1)
      write(*,'(a)') ' . . . . . . '
      write(*,'(a,i2, a, 100e7.1e1)') &
      'row = ', ni - 1, ', ', var(ni-1,2:nj-1)
      write(*,'(a,i2, a, 100e7.1e1)') &
      'row = ', ni, ', ', var(ni,2:nj-1)
      write(*,*) ''
    else
      write(*,*) 'unknow option '//opt//' in routine print_r2d in module mod_io'
      stop
    end if

  else

    do i = 1, ni
      write(*,'(100e7.1e1)') var(i,:)
    end do

  end if
  
end subroutine print_r2d

subroutine print_r1d (var) !{{{1
! print 1d array in a nice way
  
  real (kind=wp) :: var(:)

  write(*,'(100i5)') int(var(:))

end subroutine print_r1d

subroutine print_i3d (var) !{{{1
! print 3d integer array in a nice way
  
  integer :: var(:,:,:)
  integer :: ni, nj, nk, i, j, k

  ni = size(var, 1)
  nj = size(var, 2)
  nk = size(var, 3)

  do k = 1, nk
    do i = 1, ni
      write(*,"(100i3)") var(i,:,k)
    end do

    write (*,*) ''
  end do
  
end subroutine print_i3d

subroutine print_i2d (var, opt) !{{{1
! print 2d array in a nice way
  
  integer :: var(:,:)
  character (len=*), optional :: opt ! print boundary 

  integer :: ni, nj, i, j

  ni = size(var, 1)
  nj = size(var, 2)

  if ( present(opt) )then

    ! print east west boundary
    if ( opt .eq. 'ew' ) then
      do i = 2, ni - 1
        write(*,'(2i3, a, 2i3)') &
          var(i,1), var(i,2), ' . . . ', var(i,nj-1), var(i,nj)
      end do
    ! print north south
    else if ( opt .eq. 'ns' ) then
      write(*,'(a,i2, a, 100i3)') &
        ', row = ', 1, ', ', var(1,2:nj-1)
      write(*,'(a,i2, a, 100i3)') &
      ', row = ', 2, ', ', var(2,2:nj-1)
      write(*,'(a)') ' . . . . . . '
      write(*,'(a,i2, a, 100i3)') &
      ', row = ', ni - 1, ', ', var(ni-1,2:nj-1)
      write(*,'(a,i2, a, 100i3)') &
      ', row = ', ni, ', ', var(ni,2:nj-1)
      write(*,*) ''
    else
      write(*,*) 'unknow option '//opt//' in routine print_i2d in module mod_io'
      stop
    end if

  else

    do i = 1, ni
      write(*,'(100i3)') int(var(i,:))
    end do

  end if
  
end subroutine print_i2d


function type_days_month (y, m) !{{{1
  ! calc. days of a specific month of a specific year
  integer, intent(in) :: y, m
  integer :: type_days_month

  integer :: days(12)

!  days(:) = (/31, 28, 31, 30, &
!              31, 30, 31, 31, &
!              30, 31, 30, 31/)
  days(:) = 30

  type_days_month = days(m)

!  if ( m == 2 ) then
!    if ( type_days_year (y) == 366 ) type_days_month = 29
!  end if

end function type_days_month


function type_days_year (y) !{{{1
  ! calc. days of a specific year
  integer, intent(in) :: y
  integer :: type_days_year

  if (y <= 0) stop 'year should be positive in function type_days_year'
  
  type_days_year = 365

  if ( mod(y, 100) == 0 ) then
    if ( mod(y, 400) == 0 ) type_days_year = 366
  else
    if ( mod(y, 4)   == 0 ) type_days_year = 366
  end if

end function type_days_year

subroutine print_type_time(var) !{{{1
  ! print self defined type of type_time
  
  type (type_time) :: var

  ! print as the form of yyyy-mm-dd hh:mm:ss
  write(*,'(i0.4,a,i0.2,a,i0.2,x,i0.2,a,i0.2,a,i0.2)') &
    var % y, '-', var % m,  '-', var % d, &
    var % h, ':', var % mi, ':', var % s
  
end subroutine print_type_time

function time_lt_string (t, s) !{{{1
  ! user should check s first to see whether it is a proper date string

  type (type_time), intent(in) :: t
  character (len=*), intent(in) :: s
  logical :: time_lt_string

  character (len=14) :: s1, s2

  write( s1(1:4),  '(i4)') t % y
  write( s1(5:6),  '(i2)') t % m
  write( s1(7:8),  '(i2)') t % d
  write( s1(9:10), '(i2)') t % h
  write( s1(11:12),'(i2)') t % mi
  write( s1(13:14),'(i2)') t % s

  s2(1:4)   = s(1:4)
  s2(5:6)   = s(6:7)
  s2(7:8)   = s(9:10)
  s2(9:10)  = s(12:13)
  s2(11:12) = s(15:16)
  s2(13:44) = s(18:19)

  time_lt_string = llt(s1, s2)

end function time_lt_string

function type_time2sec ( t ) !{{{1
  ! how many seconds of the current time from 0001-01-01 00:00:00
  ! Note: this algorithm donot consider any history 'mistakes' for calendar
  !   the result of this routine have been compare to NCL 6.1.0's build-in
  !   function (see ou_string2time in ~/archive/ncl.ncl). But NCL thinks 
  !   there are 2*24*60*60 seconds for 0100-03-01 00:00:00 since 
  !   0100-02-28 00:00:00, obviously it treat 100 as a leap year (but also the
  !   built-in function isleapyear does not treat 100 as a leap year), so I
  !   think NCL has bugs in determine seconds from a date.
  !                  OU Niansen  2015-09-24

  type (type_time) :: t
  real (kind=wp) :: type_time2sec

  integer :: i

  type_time2sec = 0

  do i = 1, t%y - 1
    type_time2sec = type_time2sec + type_days_year (i) * 24*60*60 
  end do

  do i = 1, t%m - 1
    type_time2sec = type_time2sec + type_days_month (t%y, i) * 24*60*60 
  end do

  ! day start at 1
  type_time2sec = type_time2sec + (t%d - 1) * 24*60*60 

  ! hour/minute/second are start at 0 
  type_time2sec = type_time2sec + t%h * 60*60 + t%mi * 60 + t%s

end function type_time2sec

function type_str2sec ( str ) !{{{1
  ! how many seconds from string like "0001-01-01 00:00:00"
  character (len=*), intent(in) :: str
  integer*8 :: type_str2sec

  type (type_time) :: t

  t = type_str2time(str)
  type_str2sec = type_time2sec ( t )

end function type_str2sec


function type_str2time (str) !{{{1
  ! type_time plus an integer (in seconds)
  character (len=*), intent(in) :: str
  type (type_time) :: type_str2time

  integer :: leng, i, n
  character (len=80) :: str_num

  leng = len_trim(str)

  ! select digits character 

  ! will not successfully trim blanks without this line
  str_num = repeat('', len(str_num))

  n = 0
  do i = 1, leng
    if ( lge(str(i:i),'0') .and. lle(str(i:i),'9') ) then
      n = n + 1
      str_num(n:n) = str(i:i)
    end if
  end do

  if ( len_trim(str_num) /= 14 ) stop 'str in type_str2time should be in the form of yyyy-mm-dd hh:mm:ss'

  read(str_num(1:4), '(i4)') type_str2time % y
  if ( type_str2time % y <= 0 ) &
    stop 'year should be greater than 0 in the input string in function type_str2time'

  read(str_num(5:6), '(i2)') type_str2time % m
  type_str2time % mm = type_days_month (type_str2time%y, type_str2time%m)
  if ( type_str2time % m <= 0 .or. type_str2time % m > type_str2time % mm ) then
    write (*, '(a,i2,a)') &
      'month should be between 1-', type_str2time % mm, &
      ' in the input string for the specified year in function type_str2time '
    stop
  end if

  read(str_num(7:8), '(i2)') type_str2time % d
  if ( type_str2time % d <= 0 .or. type_str2time % d > 31 ) &
    stop 'day should be between 1-31 in the input string in function type_str2time '

  read(str_num(9:10), '(i2)') type_str2time % h
  if ( type_str2time % h < 0 .or. type_str2time % h > 23 ) &
    stop 'hour should be between 0-23 in the input string in function type_str2time '

  read(str_num(11:12), '(i2)') type_str2time % mi
  if ( type_str2time % mi < 0 .or. type_str2time % mi > 59 ) &
    stop 'miniute should be between 0-59 in the input string in function type_str2time '

  read(str_num(13:14), '(i2)') type_str2time % s
  if ( type_str2time % s < 0 .or. type_str2time % s > 59 ) &
    stop 'second should be between 0-59 in the input string in function type_str2time '

end function type_str2time

function time_plus_integer (t, dt) !{{{1
  ! type_time plus an integer (in seconds)
  type (type_time), intent(in) :: t
  integer, intent(in) :: dt

  type (type_time) :: time_plus_integer

  if (dt > 24*60*60) stop 'dt should less than a day in function time_plus_integer'

  time_plus_integer = t
  time_plus_integer % s = time_plus_integer % s + dt

  if (time_plus_integer % s >= 60) then
    time_plus_integer % mi = time_plus_integer % mi + time_plus_integer % s / 60
    time_plus_integer % s  = mod(time_plus_integer % s, 60)
  end if

  if (time_plus_integer % mi >= 60) then
    time_plus_integer % h  = time_plus_integer % h + time_plus_integer % mi / 60
    time_plus_integer % mi = mod(time_plus_integer % mi, 60)
  end if

  if (time_plus_integer % h >= 24) then
    time_plus_integer % d = time_plus_integer % d + time_plus_integer % h / 24
    time_plus_integer % h = mod(time_plus_integer % h, 24)
  end if

  if (time_plus_integer % d > time_plus_integer % mm) then
    ! dt is no more than one day
    time_plus_integer % m = time_plus_integer % m + 1
    time_plus_integer % d = 1
  end if

  if (time_plus_integer % m > 12) then
    time_plus_integer % y = time_plus_integer % y + 1
    time_plus_integer % m = 1
  end if

  time_plus_integer % mm = type_days_month (time_plus_integer%y, time_plus_integer%m)

  return

end function time_plus_integer

subroutine check_date_string (str) !{{{1
  ! check a string for whether it represents a proper date
  character (len=*), intent(in) :: str

  integer :: leng, i, n, &
    y, m, d, h, mi, s, mm
  character (len=80) :: str_num

  leng = len_trim(str)

  ! select digits character 

  ! will not successfully trim blanks without this line
  str_num = repeat('', len(str_num))

  n = 0
  do i = 1, leng
    if ( lge(str(i:i),'0') .and. lle(str(i:i),'9') ) then
      n = n + 1
      str_num(n:n) = str(i:i)
    end if
  end do

  if ( len_trim(str_num) /= 14 ) stop 'str in check_date_string should be in the form of yyyy-mm-dd hh:mm:ss'

  read(str_num(1:4), '(i4)') y
  if ( y <= 0 ) &
    stop 'year should be greater than 0 in the input string in subroutine check_date_string'

  read(str_num(5:6), '(i2)') m
  mm = type_days_month (y, m)
  if ( m <= 0 .or. m > mm ) then
    write (*, '(a,i2,a)') &
      'month should be between 1-', mm, &
      ' in the input string for the specified year in subroutine check_date_string '
    stop
  end if

  read(str_num(7:8), '(i2)') d
  if ( d <= 0 .or. d > 31 ) &
    stop 'day should be between 1-31 in the input string in subroutine check_date_string '

  read(str_num(9:10), '(i2)') h
  if ( h < 0 .or. h > 23 ) &
    stop 'hour should be between 0-23 in the input string in subroutine check_date_string '

  read(str_num(11:12), '(i2)') mi
  if ( mi < 0 .or. mi > 59 ) &
    stop 'miniute should be between 0-59 in the input string in subroutine check_date_string '

  read(str_num(13:14), '(i2)') s
  if ( s < 0 .or. s > 59 ) &
    stop 'second should be between 0-59 in the input string in subroutine check_date_string '

end subroutine check_date_string

subroutine chk( ista ) !{{{1
  ! check state of allocate array 

  integer, intent(in) ::  ista

  if ( ista /= 0 ) then
    write(*,*) 'Allocate array failed. Stop'
    stop 2
  end if
end subroutine chk

end module mod_type !{{{1
!-------------------------------------------------------{{{1
! vim:fdm=marker:fdl=0:
! vim:foldtext=getline(v\:foldstart).'...'.(v\:foldend-v\:foldstart):
