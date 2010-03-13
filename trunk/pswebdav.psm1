<# 
pswebdav v0.01
Copyright © 2010 Jorge Matos
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

#Module Variables
$script:ServicePointManagerConfigured = $false
$script:username = "" 
$script:password =  ""
$script:domain = ""
$script:certificate = "" #path to certificate file (.p12)
$script:certificate_password = ""

function ConfigureServicePointManager()
{
    if (!$script:ServicePointManagerConfigured)
    {
        Add-Type @'
        public class AcceptAll : System.Net.ICertificatePolicy 
        {	      
    	      public bool CheckValidationResult(System.Net.ServicePoint sp, System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem) 
              {
    	        return true;
    	      }
        }	
'@    
	
    	[System.Net.ServicePointManager]::CertificatePolicy = (new-object AcceptAll)
               
        $script:ServicePointManagerConfigured = $true
    }
}

function SetupCertificate($request)
{
    if (![string]::IsNullOrEmpty($script:certificate))
    {
        Assert !(Test-Path $script:certificate) "File not found: $script:certificate"
        Assert ![string]::IsNullOrEmpty($script:certificate_password) '$script:certificate_password cannot be null or empty'
          
        $cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList $script:certificate,$script:certificate_password
        [void]$request.ClientCertificates.Add($cert)
    }
}

function SetupCredentials($request)
{
    if (![string]::IsNullOrEmpty($script:username) -AND ![string]::IsNullOrEmpty($script:password))
    {   
        if (![string]::IsNullOrEmpty($script:domain))
        {
            $request.Credentials = new-object System.Net.NetworkCredential($script:username, $script:password, $script:domain)
        }
        else
        {
            $request.Credentials = new-object System.Net.NetworkCredential($script:username, $script:password)
        }
        
        $authInfo = $script:username + ":" + $script:password
        $authInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::Default.GetBytes($authInfo))
        $request.Headers["Authorization"] = "Basic " + $authInfo
    }
}

function Assert($condition, $message)
{
    if (!$condition)
    {
        throw $message
    }
}

function Get-WebDav($url, $localfilename)
{
    Assert ![string.IsNullOrEmpty($url) '$url cannot be null or empty'
    Assert ![string.IsNullOrEmpty($localfilename) '$localfilename cannot be null or empty'
	Assert (split-path $localfilename -IsAbsolute) '$localfilename must have an absolute path'

	ConfigureServicePointManager
    
    $request = [System.Net.WebRequest]::Create($url)
    
    SetupCertificate $request
    SetupCredentials $request
    
    $request.UserAgent = "PSWebDav"
    $request.Method = "GET"
   
	$response = $request.GetResponse()
	
	if ($response -ne $null)
    {		
		try
		{
			$networkStream = $response.GetResponseStream()
			$fileStream = [System.IO.File]::Create($localfilename)
			[byte[]]$buffer = new-object byte[] 16kb
			$count = $networkStream.Read($buffer, 0, $buffer.length)
			while ($count -gt 0)
			{
				$fileStream.Write($buffer, 0, $count)
				$count = $networkStream.Read($buffer, 0, $buffer.length)
			}
		}
		finally
		{		
			$networkStream.Dispose()
			$fileStream.Dispose()
		}
    }
	return $response.StatusCode
}

function Get-WebDavFileList($url, $depth = 1)
{
    Assert ![string.IsNullOrEmpty($url) '$url cannot be null or empty'
    
	$uri = new-object system.uri $url
	$baseDir = $uri.segments[$uri.segments.length-1]
	
    ConfigureServicePointManager
    
    $request = [System.Net.WebRequest]::Create($url)
    
    SetupCertificate $request
	SetupCredentials $request
    
    $webdav_request_xml = @'
            <?xml version="1.0" encoding="utf-8" ?>
            <a:propfind xmlns:a="DAV:">
                <a:propname/>
            </a:propfind>
'@
        
    $request.UserAgent = "PSWebDav"
    $request.Method = "PROPFIND"
    $request.Headers.Set("Depth", $depth)
     
    $requestStream = $request.GetRequestStream()
    $requestBytes = [System.Text.Encoding]::UTF8.GetBytes($webdav_request_xml)
    $requestStream.Write($requestBytes, 0, $requestBytes.Length)
    $requestStream.Close()
            
    $response = $request.GetResponse()
	
	$results = @()
	
	if ($response -ne $null)
    {
		$results += "Status Code = " + $response.StatusCode
        $sr = new-object System.IO.StreamReader -ArgumentList $response.GetResponseStream(),[System.Encoding]::Default
        [xml]$xml = $sr.ReadToEnd()		
        $results += $xml.multistatus.response | % { $_.propstat.prop } | ? { $_.displayName -ne "" -and $_.displayName -ne $baseDir} | select @{Name="type"; Expression = { if ($_.resourceType -eq "") {return "file"} else {return "directory"}  }}, displayname,  @{Name="size"; Expression = { if ($_.resourceType -eq "") {return $_.getcontentlength} else {return ""}  }}, creationdate, getlastmodified | sort type
    }     
	return $results 	
}

function New-WebDavDirectory($url)
{
    Assert ![string.IsNullOrEmpty($url) '$url cannot be null or empty'
    
    ConfigureServicePointManager
        
    $request = [System.Net.WebRequest]::Create($url)
    
    SetupCertificate $request
    SetupCredentials $request
    
    $request.UserAgent = "PSWebDav"
    $request.Method = "MKCOL"
           
    $response = $request.GetResponse()
	return $response.StatusCode
}

function Remove-WebDav($url)
{
    Assert ![string.IsNullOrEmpty($url) '$url cannot be null or empty'
    
    ConfigureServicePointManager
    
    $request = [System.Net.WebRequest]::Create($url)
    
    SetupCertificate $request
    SetupCredentials $request
        
    $request.UserAgent = "PSWebDav"
    $request.Method = "DELETE"
           
    $response = $request.GetResponse()
	return $response.StatusCode
}

function Send-WebDav($url, $fileToUpload)
{
    Assert ![string.IsNullOrEmpty($url) '$url cannot be null or empty'
    Assert !(Test-Path $fileToUpload) "File not found: $fileToUpload"
    
    ConfigureServicePointManager

    $request = [System.Net.WebRequest]::Create($url)    
    
    SetupCredentials $request
    SetupCertificate $request
      
    $request.UserAgent = "PSWebDav"
    $request.Method = "PUT"
    $request.PreAuthenticate = $true
    $request.ContentType = "text/xml"
    
	$buffer = new-object byte[] 16kb		
    $requestStream = $request.GetRequestStream()        	
	$fileStream = [System.IO.File]::OpenRead((Resolve-path $fileToUpload).Path)
	
	try
	{		
		$bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
		while ($bytesRead -gt 0)
		{
			$requestStream.Write($buffer, 0, $bytesRead)
			$bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
		}	
    }
	finally
	{	
		$fileStream.Close()
		$requestStream.Close()
	}
                
    $response = $request.GetResponse()
	return $response.StatusCode
}

Export-ModuleMember -Function Get-WebDav, Get-WebDavFileList, New-WebDavDirectory, Remove-WebDav, Send-WebDav