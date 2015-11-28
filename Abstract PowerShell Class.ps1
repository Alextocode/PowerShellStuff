<#
 # How to emulate an abstract class in PowerShell 5 
 #>

<# abstract #> class ParentClass
{
    # Just a little property so it looks more authentic
    static 
    [System.Collections.Hashtable]
    $foo = @{}
    
    # A special constructor that blocks the creation of the class but not any subclasses
     ParentClass()
    {
  
       if($this.toString() -eq "ParentClass") #class name here.....
       {
            $this = $null
            throw "Can not create instance of abstract class"
       } 
   
    }
}    

<# concrete #> class Subclass : ParentClass
{
    Subclass()
    {
        Write-Host "I was created."
    }
}

####################
# now some testing #
####################

[ParentClass]::new()
# will throw a runtime exception and the error message defined in throw statement

[SubClass]::new()
# works and will print "I was created" in the command line




