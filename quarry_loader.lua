-- Load stalink installation path
if not StalinkInstallationPath then
  local StalinkInstallationPathFile = fs.open("/stalink-path", "r")
  StalinkInstallationPath = StalinkInstallationPathFile.readLine()
  StalinkInstallationPathFile.close()
end

if not StalinkInstallationPath then
  error("Cannot read stalink-path file")
end

os.loadAPI(StalinkInstallationPath .. "turtle/quarry_mining/auto_quarry.lua")
