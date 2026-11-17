-- =====================================================================
-- PrimeiroPasso / Ventrya API - DDL dos objetos de banco (Oracle)
-- Consolidado a partir das migrations Flyway (ventrya-api/src/main/resources/db/migration)
-- Na nuvem, o Flyway aplica estas migrations automaticamente na subida da API.
-- Use este arquivo apenas para criar o schema manualmente em um banco vazio.
-- =====================================================================

-- ---------------------------------------------------------------------
-- V1__create_user.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_users START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE TABLE ventrya_user(
                     id NUMBER(19,0) PRIMARY KEY,
                     name VARCHAR2(255 CHAR) NOT NULL,
                     email VARCHAR2(255 CHAR) NOT NULL,
                     password VARCHAR2(255 CHAR) NOT NULL,
                     professional_area VARCHAR2(255 CHAR) NOT NULL,
                     created_At TIMESTAMP(6) NOT NULL,
                     role VARCHAR2(255 CHAR) NOT NULL,

                     CONSTRAINT uk_users_email UNIQUE (email)

);

-- ---------------------------------------------------------------------
-- V2__create_organization.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_organization
START WITH 1
INCREMENT BY 1
NOCACHE;

CREATE TABLE ventrya_organization (
    id NUMBER(19,0) PRIMARY KEY,
    name VARCHAR2(255 CHAR) NOT NULL,
    email VARCHAR2(255 CHAR) NOT NULL,
    description VARCHAR2(2000 CHAR) NOT NULL,
    web_site VARCHAR2(255 CHAR),
    created_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT uk_ventrya_organization_email UNIQUE (email)
);

-- ---------------------------------------------------------------------
-- V3__create_organization_user.sql
-- ---------------------------------------------------------------------
CREATE TABLE ventrya_organization_user (
    organization_id NUMBER(19,0) NOT NULL,
    user_id NUMBER(19,0) NOT NULL,

    CONSTRAINT pk_ventrya_organization_user
        PRIMARY KEY (organization_id, user_id),

    CONSTRAINT fk_ventrya_org_user_organization
        FOREIGN KEY (organization_id)
        REFERENCES ventrya_organization(id),

    CONSTRAINT fk_ventrya_org_user_user
        FOREIGN KEY (user_id)
        REFERENCES ventrya_user(id)
);

-- ---------------------------------------------------------------------
-- V4__create_challenge.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_challenge START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE TABLE ventrya_challenge(
    id NUMBER(19,0) PRIMARY KEY,
    title VARCHAR2(255 CHAR) NOT NULL,
    description VARCHAR2(2000 CHAR) NOT NULL,
    professional_area VARCHAR2(255 CHAR) NOT NULL,
    difficulty VARCHAR2(255 CHAR) NOT NULL,
    requirements VARCHAR2(2000 CHAR),
    dead_line DATE NOT NULL,
    status VARCHAR2(255 CHAR) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    organization_id NUMBER(19,0) NOT NULL,

    CONSTRAINT fk_ventrya_challenge_organization
        FOREIGN KEY (organization_id)
        REFERENCES ventrya_organization(id)
);

-- ---------------------------------------------------------------------
-- V5__create_application.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_application
    START WITH 1
    INCREMENT BY 1 NOCACHE;

CREATE TABLE ventrya_application (
    id NUMBER(19,0) PRIMARY KEY,
    student_id NUMBER(19,0) NOT NULL,
    challenge_id NUMBER(19,0) NOT NULL,
    status VARCHAR2(255 CHAR) NOT NULL,
    applied_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT fk_ventrya_application_student
        FOREIGN KEY (student_id)
        REFERENCES ventrya_user(id),

    CONSTRAINT fk_ventrya_application_challenge
        FOREIGN KEY (challenge_id)
        REFERENCES ventrya_challenge(id),

    CONSTRAINT uk_ventrya_application_student_challenge
        UNIQUE (student_id, challenge_id)
);

-- ---------------------------------------------------------------------
-- V6__create_submission.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_submission
    START WITH 1
    INCREMENT BY 1 NOCACHE;

CREATE TABLE ventrya_submission (
    id NUMBER(19,0) PRIMARY KEY,
    application_id NUMBER(19,0) NOT NULL,
    description VARCHAR2(2000 CHAR) NOT NULL,
    file_url VARCHAR2(255 CHAR),
    status VARCHAR2(255 CHAR) NOT NULL,
    submitted_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT fk_ventrya_submission_application
        FOREIGN KEY (application_id)
        REFERENCES ventrya_application(id),

    CONSTRAINT uk_ventrya_submission_application
        UNIQUE (application_id)
);


-- ---------------------------------------------------------------------
-- V7__create_feedback.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_feedback
START WITH 1
INCREMENT BY 1
NOCACHE;

CREATE TABLE ventrya_feedback (
    id NUMBER(19,0) PRIMARY KEY,
    submission_id NUMBER(19,0) NOT NULL,
    feedback_comment VARCHAR2(2000 CHAR) NOT NULL,
    rating NUMBER(10,0),
    strengths VARCHAR2(2000 CHAR),
    improvements VARCHAR2(2000 CHAR),
    created_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT fk_ventrya_feedback_submission
        FOREIGN KEY (submission_id)
        REFERENCES ventrya_submission(id),

    CONSTRAINT uk_ventrya_feedback_submission
        UNIQUE (submission_id),

    CONSTRAINT ck_ventrya_feedback_rating
        CHECK (rating BETWEEN 1 AND 5)
);


-- ---------------------------------------------------------------------
-- V8__create_portfolio.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_portfolio
    START WITH 1
    INCREMENT BY 1 NOCACHE;

CREATE TABLE ventrya_portfolio (
    id NUMBER(19,0) PRIMARY KEY,
    student_id NUMBER(19,0) NOT NULL,
    submission_id NUMBER(19,0) NOT NULL,
    title VARCHAR2(255 CHAR) NOT NULL,
    generated_description VARCHAR2(4000 CHAR),
    skills VARCHAR2(2000 CHAR),
    status VARCHAR2(255 CHAR) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT fk_ventrya_portfolio_student
        FOREIGN KEY (student_id)
        REFERENCES ventrya_user(id),

    CONSTRAINT fk_ventrya_portfolio_submission
        FOREIGN KEY (submission_id)
        REFERENCES ventrya_submission(id),

    CONSTRAINT uk_ventrya_portfolio_submission
        UNIQUE (submission_id)
);


-- ---------------------------------------------------------------------
-- V9__create_interview.sql
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_ventrya_interview
    START WITH 1
    INCREMENT BY 1 NOCACHE;

CREATE TABLE ventrya_interview (
    id NUMBER(19,0) PRIMARY KEY,
    student_id NUMBER(19,0) NOT NULL,
    professional_area VARCHAR2(255 CHAR) NOT NULL,
    question VARCHAR2(2000 CHAR) NOT NULL,
    answer VARCHAR2(4000 CHAR),
    ai_feedback VARCHAR2(4000 CHAR),
    created_at TIMESTAMP(6) NOT NULL,

    CONSTRAINT fk_ventrya_interview_student
        FOREIGN KEY (student_id)
        REFERENCES ventrya_user(id)
);


-- ---------------------------------------------------------------------
-- V10__update_interview_and_create_interview_question.sql
-- ---------------------------------------------------------------------
-- 1. Atualizar a tabela de entrevistas

ALTER TABLE ventrya_interview ADD (
    status VARCHAR2(30) DEFAULT 'IN_PROGRESS' NOT NULL,
    overall_feedback VARCHAR2(4000),
    completed_at TIMESTAMP
);

-- 2. Remover os campos que agora pertencem às perguntas

ALTER TABLE ventrya_interview DROP (
    question,
    answer,
    ai_feedback
);

-- 3. Criar a sequence da nova entidade

CREATE SEQUENCE seq_ventrya_interview_question
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 4. Criar a tabela de perguntas

CREATE TABLE ventrya_interview_question (
    id NUMBER(19) NOT NULL,
    interview_id NUMBER(19) NOT NULL,
    question_number NUMBER(10) NOT NULL,
    question VARCHAR2(2000) NOT NULL,
    answer VARCHAR2(4000),
    ai_feedback VARCHAR2(4000),

    CONSTRAINT pk_ventrya_interview_question
        PRIMARY KEY (id),

    CONSTRAINT fk_ventrya_interview_question
        FOREIGN KEY (interview_id)
        REFERENCES ventrya_interview(id),

    CONSTRAINT uk_interview_question_number
        UNIQUE (interview_id, question_number),

    CONSTRAINT ck_interview_question_number
        CHECK (question_number BETWEEN 1 AND 5)
);
