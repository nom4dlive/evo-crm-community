configs = [
  { name: 'STORAGE_ACCESS_KEY_ID', value: 'local' },
  { name: 'STORAGE_ACCESS_SECRET', value: 'local' },
  { name: 'STORAGE_REGION', value: 'us-east-1' },
  { name: 'STORAGE_BUCKET_NAME', value: 'local' },
  { name: 'STORAGE_ENDPOINT', value: 'http://localhost:3001' },
  { name: 'MAILER_TYPE', value: 'smtp' },
  { name: 'SMTP_HOST', value: 'smtp.hostinger.com' },
  { name: 'SMTP_PORT', value: '465' },
  { name: 'SMTP_USERNAME', value: 'suporte@bodyharmony.tech' },
  { name: 'SMTP_PASSWORD_SECRET', value: 'SuporteBH2026!' },
  { name: 'SYSTEM_EMAIL', value: 'suporte@bodyharmony.tech' }
]

configs.each do |config|
  val = config[:value]
  
  if config[:name].end_with?('_SECRET')
    # Encrypt the secret before storing
    require 'fernet'
    val = Fernet.generate(InstallationConfig.encryption_key, val)
  end
  
  InstallationConfig.find_or_create_by!(name: config[:name]) do |c|
    c.serialized_value = { value: val }
  end
end

puts "✅ Initial installation configs seeded successfully!"
