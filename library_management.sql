-- ============================================================
--  Library Management System
-- ============================================================


-- 1. AUTHORS
CREATE TABLE Authors (
    author_id   NUMBER(5)    PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    nationality VARCHAR(50)
);

-- 2. CATEGORIES
CREATE TABLE Categories (
    category_id NUMBER(5)    PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255)
);

-- 3. BOOKS
CREATE TABLE Books (
    book_id          NUMBER(5)    PRIMARY KEY,
    isbn             VARCHAR(20)  NOT NULL UNIQUE,
    title            VARCHAR(150) NOT NULL,
    author_id        NUMBER(5)    NOT NULL,
    category_id      NUMBER(5)    NOT NULL,
    year_published   NUMBER(4)    CHECK (year_published BETWEEN 1000 AND 2100),
    total_copies     NUMBER(3)    NOT NULL CHECK (total_copies > 0),
    available_copies NUMBER(3)    NOT NULL CHECK (available_copies >= 0),
    CONSTRAINT fk_book_author    FOREIGN KEY (author_id)   REFERENCES Authors(author_id),
    CONSTRAINT fk_book_category  FOREIGN KEY (category_id) REFERENCES Categories(category_id),
    CONSTRAINT chk_copies        CHECK (available_copies <= total_copies)
);

-- 4. MEMBERS
CREATE TABLE Members (
    member_id  NUMBER(5)    PRIMARY KEY,
    first_name VARCHAR(50)  NOT NULL,
    last_name  VARCHAR(50)  NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    join_date  DATE         NOT NULL,
    status     VARCHAR(10)  NOT NULL CHECK (status IN ('Active', 'Inactive', 'Banned'))
);

-- 5. LOANS
CREATE TABLE Loans (
    loan_id     NUMBER(5)   PRIMARY KEY,
    book_id     NUMBER(5)   NOT NULL,
    member_id   NUMBER(5)   NOT NULL,
    loan_date   DATE        NOT NULL,
    due_date    DATE        NOT NULL,
    return_date DATE,
    status      VARCHAR(10) NOT NULL CHECK (status IN ('Active', 'Returned', 'Overdue')),
    CONSTRAINT fk_loan_book    FOREIGN KEY (book_id)   REFERENCES Books(book_id),
    CONSTRAINT fk_loan_member  FOREIGN KEY (member_id) REFERENCES Members(member_id),
    CONSTRAINT chk_due_date    CHECK (due_date > loan_date),
    CONSTRAINT chk_return      CHECK (return_date IS NULL OR return_date >= loan_date)
);


-- ============================================================
--  SAMPLE DATA
-- ============================================================

INSERT INTO Authors VALUES (1, 'George',  'Orwell',          'British');
INSERT INTO Authors VALUES (2, 'J.K.',    'Rowling',         'British');
INSERT INTO Authors VALUES (3, 'Frank',   'Herbert',         'American');
INSERT INTO Authors VALUES (4, 'Agatha',  'Christie',        'British');
INSERT INTO Authors VALUES (5, 'Gabriel', 'Garcia Marquez',  'Colombian');

INSERT INTO Categories VALUES (1, 'Fiction',          'Imaginative and narrative works');
INSERT INTO Categories VALUES (2, 'Science Fiction',  'Futuristic science and technology themes');
INSERT INTO Categories VALUES (3, 'Mystery',          'Suspense, crime and detective stories');
INSERT INTO Categories VALUES (4, 'Fantasy',          'Magic, mythology and supernatural elements');
INSERT INTO Categories VALUES (5, 'Classic',          'Timeless literary works');

INSERT INTO Books VALUES (1, '978-0451524935', '1984',                          1, 5, 1949, 5, 4);
INSERT INTO Books VALUES (2, '978-0439708180', 'Harry Potter Sorcerers Stone',  2, 4, 1997, 8, 6);
INSERT INTO Books VALUES (3, '978-0441013593', 'Dune',                          3, 2, 1965, 4, 4);
INSERT INTO Books VALUES (4, '978-0007119318', 'Murder on the Orient Express',  4, 3, 1934, 3, 2);
INSERT INTO Books VALUES (5, '978-0060883287', 'One Hundred Years of Solitude', 5, 1, 1967, 3, 3);

INSERT INTO Members VALUES (1, 'Alice', 'Johnson', 'alice@email.com', DATE '2023-01-15', 'Active');
INSERT INTO Members VALUES (2, 'Bob',   'Smith',   'bob@email.com',   DATE '2023-03-22', 'Active');
INSERT INTO Members VALUES (3, 'Clara', 'Davis',   'clara@email.com', DATE '2023-05-10', 'Active');
INSERT INTO Members VALUES (4, 'David', 'Wilson',  'david@email.com', DATE '2022-11-01', 'Inactive');
INSERT INTO Members VALUES (5, 'Emma',  'Brown',   'emma@email.com',  DATE '2024-01-08', 'Active');

INSERT INTO Loans VALUES (1, 1, 1, DATE '2024-05-01', DATE '2024-05-15', DATE '2024-05-13', 'Returned');
INSERT INTO Loans VALUES (2, 2, 2, DATE '2024-05-10', DATE '2024-05-24', NULL,              'Active');
INSERT INTO Loans VALUES (3, 4, 3, DATE '2024-04-20', DATE '2024-05-04', DATE '2024-05-01', 'Returned');
INSERT INTO Loans VALUES (4, 1, 4, DATE '2024-03-01', DATE '2024-03-15', NULL,              'Overdue');
INSERT INTO Loans VALUES (5, 5, 5, DATE '2024-05-12', DATE '2024-05-26', NULL,              'Active');

COMMIT;
