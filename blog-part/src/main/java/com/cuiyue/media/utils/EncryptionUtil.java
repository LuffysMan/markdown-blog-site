package com.cuiyue.media.utils;

import org.jasypt.encryption.StringEncryptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;

public class EncryptionUtil {
    @Autowired
    @Qualifier("jasyptStringEncryptor")
    private StringEncryptor encryptor;

    public String encrypt(String plaintext) {

        return encryptor.encrypt(plaintext);
    }

    public String decrypt(String encryptedData) {
        return encryptor.decrypt(encryptedData);
    }
}