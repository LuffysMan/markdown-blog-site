package com.cuiyue.media.config;

import org.jasypt.encryption.StringEncryptor;
import org.jasypt.encryption.pbe.PooledPBEStringEncryptor;
import org.jasypt.encryption.pbe.config.SimpleStringPBEConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.PropertySource;

import java.util.Iterator;

public class JasyptDecryptProcessor {

    private StringEncryptor encryptor;

    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        // 初始化加解密器
        this.encryptor = buildEncryptor(environment);

        // 遍历所有 PropertySource
        Iterator<PropertySource<?>> it = environment.getPropertySources().iterator();
        while (it.hasNext()) {
            PropertySource<?> ps = it.next();
            if (ps.getSource() instanceof java.util.Map) {
                decryptPropertySource((PropertySource<?>) ps);
            }
        }
    }

    private StringEncryptor buildEncryptor(ConfigurableEnvironment environment) {
        String password = environment.getProperty("jasypt.encryptor.password");
        if (password == null) {
            password = System.getenv("JASYPT_ENCRYPTOR_PASSWORD"); // 从环境变量读取
        }

        PooledPBEStringEncryptor encryptor = new PooledPBEStringEncryptor();
        SimpleStringPBEConfig config = new SimpleStringPBEConfig();
        config.setPassword(password);
        config.setAlgorithm("PBEWITHHMACSHA512ANDAES_256");
        config.setKeyObtentionIterations("1000");
        config.setPoolSize("1");
        config.setStringOutputType("base64");
        encryptor.setConfig(config);
        return encryptor;
    }

    private void decryptPropertySource(PropertySource<?> ps) {
        if (!(ps.getSource() instanceof java.util.Map)) {
            return;
        }
        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> map = (java.util.Map<String, Object>) ps.getSource();

        for (java.util.Map.Entry<String, Object> entry : map.entrySet()) {
            Object value = entry.getValue();
            if (value instanceof String strVal && strVal.startsWith("ENC(") && strVal.endsWith(")")) {
                String encValue = strVal.substring(4, strVal.length() - 1);
                try {
                    String decValue = encryptor.decrypt(encValue);
                    entry.setValue(decValue);
                } catch (Exception e) {
                    throw new IllegalStateException("解密失败: " + entry.getKey(), e);
                }
            }
        }
    }
}
